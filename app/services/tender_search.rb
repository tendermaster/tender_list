# frozen_string_literal: true

module TenderSearch
  extend self

  # Weights for field importance: title > description > organisation > state
  WEIGHTS = {
    title: 3.0,
    description: 2.0,
    organisation: 1.5,
    state: 1.0
  }.freeze

  SNAPSHOT_TTL = 120.seconds  # 2 minutes
  MAX_SNAPSHOT_SIZE = 1000    # Max ranked results to cache

  # ─────────────────────────────────────────────────────────────────────────────
  # PHASE 1: Search with Snapshot
  # ─────────────────────────────────────────────────────────────────────────────

  # Search with weighted BM25 scoring using snapshot-based pagination
  # @param query [String] search query
  # @param page [Integer] page number (1-indexed)
  # @param per_page [Integer] results per page
  # @return [Array<Pagy, Array<Tender>>]
  def weighted_search(query, page = 1, per_page: 5)
    page = [page.to_i, 1].max
    query = query.to_s.squish

    return [Pagy.new(count: 0, page: 1, items: per_page), []] if query.blank?

    # Dynamic Limit: If user requests page 1000, we need at least 5000 results.
    # We scale the snapshot size only when necessary to keep standard searches fast.
    needed_limit = page * per_page
    effective_limit = [needed_limit, MAX_SNAPSHOT_SIZE].max

    # Get or create snapshot with the required limit
    snapshot = get_or_create_snapshot(query, limit: effective_limit)

    # Calculate position range
    from_pos = ((page - 1) * per_page) + 1

    # Fetch page from snapshot
    page_ids = snapshot[:ids].slice((from_pos - 1), per_page) || []

    pagy = Pagy.new(count: snapshot[:total], page: page, items: per_page)
    records = fetch_tenders_in_order(page_ids)

    [pagy, records]
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # PHASE 2: Similar Tenders (MLT) with Snapshot
  # ─────────────────────────────────────────────────────────────────────────────

  # Find similar tenders using source tender's content
  # @param source_tender [Tender] the reference tender
  # @param exclude_id [Integer] ID to exclude from results
  # @param limit [Integer] max results
  # @return [Array<Tender>]
  def similar_tenders(source_tender, exclude_id, limit: 10)
    return [] if source_tender.nil?

    # Use title if it's meaningful, otherwise use description
    query_text = if source_tender.title.to_s.match?(/^[A-Z0-9\-\/]+$/)
      source_tender.description
    else
      source_tender.title
    end

    return [] if query_text.blank?

    # MLT snapshot key
    cache_key = "mlt:#{exclude_id}:#{Digest::MD5.hexdigest(query_text.squish)}"

    ids = Rails.cache.fetch(cache_key, expires_in: SNAPSHOT_TTL) do
      compute_mlt_ranking(query_text.squish, exclude_id, limit: limit)
    end

    fetch_tenders_in_order(ids)
  rescue StandardError => e
    Rails.logger.error("TenderSearch.similar_tenders failed: #{e.message}")
    []
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # PHASE 3: Count Matching Tenders (for MailerJob)
  # ─────────────────────────────────────────────────────────────────────────────

  # Count tenders matching query (replacement for tsvector count in MailerJob)
  # @param query [String] search query
  # @param since [Time] only count tenders created after this time
  # @return [Integer]
  def count_matching(query, since: nil)
    sanitized_query = ActiveRecord::Base.connection.quote(query)

    since_clause = if since
      "AND t.created_at > #{ActiveRecord::Base.connection.quote(since.utc)}"
    else
      ""
    end

    sql = <<-SQL
      WITH q AS (
        SELECT
          to_bm25query(#{sanitized_query}, 'idx_tenders_title_bm25') AS qt,
          to_bm25query(#{sanitized_query}, 'idx_tenders_description_bm25') AS qd
      )
      SELECT COUNT(DISTINCT id)
      FROM (
        -- 1. ACTIVE TENDERS
        SELECT t.id
        FROM tenders t, q
        WHERE t.is_visible = true
          AND t.submission_close_date > NOW()
          #{since_clause}
          AND (
               t.title <@> q.qt IS NOT NULL
            OR t.description <@> q.qd IS NOT NULL
          )
        UNION ALL
        -- 2. INACTIVE TENDERS (Split for Index Usage)
        SELECT t.id
        FROM tenders t, q
        WHERE t.is_visible = true
          AND t.submission_close_date <= NOW()
          #{since_clause}
          AND t.title <@> q.qt IS NOT NULL
        UNION ALL
        SELECT t.id
        FROM tenders t, q
        WHERE t.is_visible = true
          AND t.submission_close_date <= NOW()
          #{since_clause}
          AND t.description <@> q.qd IS NOT NULL
      ) AS matches
    SQL

    ActiveRecord::Base.connection.execute(sql).first['count'].to_i
  end

  private

  # ─────────────────────────────────────────────────────────────────────────────
  # Snapshot Management
  # ─────────────────────────────────────────────────────────────────────────────

  def get_or_create_snapshot(query, limit: MAX_SNAPSHOT_SIZE)
    # Include limit in cache key to separate "shallow" (fast) vs "deep" (slow) snapshots
    cache_key = "search:#{Digest::MD5.hexdigest(query)}:#{limit}"

    Rails.cache.fetch(cache_key, expires_in: SNAPSHOT_TTL) do
      compute_ranking_snapshot(query, limit: limit)
    end
  end

  # Compute BM25 ranking ONCE and store as snapshot
  #
  # OPTIMIZATION STRATEGY: "Union-of-Unions" (Candidate Fetching)
  #
  # Problem:
  #   The `tenders` table has 10M+ rows. A simple OR condition in the WHERE clause
  #   (title matches OR description matches) combined with `submission_close_date <= NOW()`
  #   causes the Postgres Query Planner to default to a Sequential Scan, taking 400s+.
  #
  # Solution:
  #   We force the usage of specific BM25 indexes by splitting the "Inactive" search
  #   into 4 separate sub-queries (one per field).
  #
  # Process:
  #   1. Define BM25 query terms in a CTE `q`.
  #   2. FETCH CANDIDATES (ID only):
  #      - Branch 1: ACTIVE TENDERS (submission_close_date > NOW())
  #        - Fast because the date filter is highly selective (~20k rows vs 10M).
  #      - Branch 2: INACTIVE TENDERS (submission_close_date <= NOW())
  #        - Split into 4 UNION parts: Title, Description, Organisation, State.
  #        - This forces Postgres to use `idx_tenders_title_bm25` etc. for each part.
  #        - We LIMIT each part to a subset (limit * 0.5) to keep the candidate pool small.
  #   3. SCORE & SORT:
  #      - We take the distinct list of candidate IDs.
  #      - We calculate the full weighted score ONLY for these rows.
  #      - We sort by Active Status first, then Score.
  #
  # Result: Execution time drops from ~400s to ~2s (for standard limits).
  def compute_ranking_snapshot(query, limit:)
    sanitized_query = ActiveRecord::Base.connection.quote(query)

    # Scale sub-query limits proportionally.
    # Base ratio: 500 sub-limit for 1000 total limit (0.5).
    sub_limit = (limit * 0.5).ceil

    sql = <<-SQL
      WITH q AS (
        SELECT
          to_bm25query(#{sanitized_query}, 'idx_tenders_title_bm25') AS qt,
          to_bm25query(#{sanitized_query}, 'idx_tenders_description_bm25') AS qd,
          to_bm25query(#{sanitized_query}, 'idx_tenders_organisation_bm25') AS qo,
          to_bm25query(#{sanitized_query}, 'idx_tenders_state_bm25') AS qs
      ),
      candidates AS (
        -- 1. ACTIVE TENDERS (Fast via Date Index + Post-Filter)
        (
          SELECT t.id
          FROM tenders t, q
          WHERE t.is_visible = true
            AND t.submission_close_date > NOW()
            AND (
                 t.title <@> q.qt IS NOT NULL
              OR t.description <@> q.qd IS NOT NULL
              OR t.organisation <@> q.qo IS NOT NULL
              OR t.state <@> q.qs IS NOT NULL
            )
          LIMIT #{limit}
        )
        UNION
        -- 2. INACTIVE TENDERS (Force Index Scans by splitting fields)
        (
          SELECT t.id FROM tenders t, q
          WHERE t.is_visible = true AND t.submission_close_date <= NOW()
            AND t.title <@> q.qt IS NOT NULL
          LIMIT #{sub_limit}
        )
        UNION
        (
          SELECT t.id FROM tenders t, q
          WHERE t.is_visible = true AND t.submission_close_date <= NOW()
            AND t.description <@> q.qd IS NOT NULL
          LIMIT #{sub_limit}
        )
        UNION
        (
          SELECT t.id FROM tenders t, q
          WHERE t.is_visible = true AND t.submission_close_date <= NOW()
            AND t.organisation <@> q.qo IS NOT NULL
          LIMIT #{sub_limit}
        )
        UNION
        (
          SELECT t.id FROM tenders t, q
          WHERE t.is_visible = true AND t.submission_close_date <= NOW()
            AND t.state <@> q.qs IS NOT NULL
          LIMIT #{sub_limit}
        )
      )
      -- 3. SCORE & SORT ONLY CANDIDATES
      SELECT
        t.id,
        (
            #{WEIGHTS[:title]} * COALESCE(t.title <@> q.qt, 0)
          + #{WEIGHTS[:description]} * COALESCE(t.description <@> q.qd, 0)
          + #{WEIGHTS[:organisation]} * COALESCE(t.organisation <@> q.qo, 0)
          + #{WEIGHTS[:state]} * COALESCE(t.state <@> q.qs, 0)
        ) AS score
      FROM tenders t, q
      WHERE t.id IN (SELECT id FROM candidates)
      ORDER BY
        (CASE WHEN t.submission_close_date > NOW() THEN 0 ELSE 1 END) ASC, -- Active First
        score DESC,
        t.id ASC
      LIMIT #{limit}
    SQL

    results = ActiveRecord::Base.connection.execute(sql)
    ids = results.map { |r| r['id'] }

    # Return snapshot with IDs and total count
    { ids: ids, total: ids.size }
  end

  # Compute MLT ranking
  def compute_mlt_ranking(query_text, exclude_id, limit:)
    sanitized_query = ActiveRecord::Base.connection.quote(query_text)

    sql = <<-SQL
      WITH q AS (
        SELECT
          to_bm25query(#{sanitized_query}, 'idx_tenders_title_bm25') AS qt,
          to_bm25query(#{sanitized_query}, 'idx_tenders_description_bm25') AS qd
      ),
      scored AS (
        SELECT
          t.id,
          (
            #{WEIGHTS[:title]} * COALESCE(t.title <@> q.qt, 0)
          + #{WEIGHTS[:description]} * COALESCE(t.description <@> q.qd, 0)
          ) AS score
        FROM tenders t, q
        WHERE t.id <> #{exclude_id.to_i}
          AND t.is_visible = true
          AND (
            t.title <@> q.qt IS NOT NULL
            OR t.description <@> q.qd IS NOT NULL
          )
      )
      SELECT id
      FROM scored
      ORDER BY score ASC, id ASC
      LIMIT #{limit.to_i}
    SQL

    results = ActiveRecord::Base.connection.execute(sql)
    results.map { |r| r['id'] }
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Utilities
  # ─────────────────────────────────────────────────────────────────────────────

  # Fetch tenders preserving order of IDs
  def fetch_tenders_in_order(ids)
    return [] if ids.blank?

    Tender.where(id: ids).index_by(&:id).values_at(*ids).compact
  end
end