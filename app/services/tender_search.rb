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
  MAX_SNAPSHOT_SIZE = 200     # Max ranked results to cache (Default: Pages 1-40)

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

    # Dynamic Limit with Cache Bucketing
    # We round up the requirement to the nearest 200 to prevent generating
    # a new snapshot for every single page increment.
    # Page 1-40  -> Limit 200
    # Page 41-80 -> Limit 400
    raw_limit = page * per_page
    needed_limit = (raw_limit / 200.0).ceil * 200
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
  # OPTIMIZATION STRATEGY: "Global KNN Aggregation"
  #
  # Process:
  #   1. Fetch Top N (limit * 5) best matches for EACH field globally using KNN Index Scans.
  #      This bypasses the 10M row scan by asking the index for the best results directly.
  #   2. Aggregate (MIN) scores per ID to merge matches across different fields.
  #   3. Weight the distances (Lower is Better) using COALESCE(..., 10000) for non-matches.
  #   4. Final Sort: Active Status first, then Weighted Distance.
  #
  # Result: ~360ms for 10M rows.
  def compute_ranking_snapshot(query, limit:)
    sanitized_query = ActiveRecord::Base.connection.quote(query)

    # We fetch a larger pool of candidates (5x the requested limit) to ensure
    # that Active tenders aren't "starved" out by better-matching Inactive ones.
    sub_limit = [limit * 5, 1000].max

    sql = <<-SQL
      WITH q AS (
        SELECT
          to_bm25query(#{sanitized_query}, 'idx_tenders_title_bm25') AS qt,
          to_bm25query(#{sanitized_query}, 'idx_tenders_description_bm25') AS qd,
          to_bm25query(#{sanitized_query}, 'idx_tenders_organisation_bm25') AS qo,
          to_bm25query(#{sanitized_query}, 'idx_tenders_state_bm25') AS qs
      ),
      candidates_raw AS (
        (
          SELECT id, (title <@> q.qt) as t_dist, NULL::float as d_dist, NULL::float as o_dist, NULL::float as s_dist
          FROM tenders t, q
          ORDER BY t.title <@> q.qt ASC
          LIMIT #{sub_limit}
        )
        UNION ALL
        (
          SELECT id, NULL::float, (description <@> q.qd), NULL::float, NULL::float
          FROM tenders t, q
          ORDER BY t.description <@> q.qd ASC
          LIMIT #{sub_limit}
        )
        UNION ALL
        (
          SELECT id, NULL::float, NULL::float, (organisation <@> q.qo), NULL::float
          FROM tenders t, q
          ORDER BY t.organisation <@> q.qo ASC
          LIMIT #{sub_limit}
        )
        UNION ALL
        (
          SELECT id, NULL::float, NULL::float, NULL::float, (state <@> q.qs)
          FROM tenders t, q
          ORDER BY t.state <@> q.qs ASC
          LIMIT #{sub_limit}
        )
      ),
      candidates_scored AS (
        SELECT
          id,
          MIN(t_dist) as t_dist,
          MIN(d_dist) as d_dist,
          MIN(o_dist) as o_dist,
          MIN(s_dist) as s_dist
        FROM candidates_raw
        GROUP BY id
      )
      SELECT
        t.id,
        (
            #{WEIGHTS[:title]} * COALESCE(c.t_dist, 10000)
          + #{WEIGHTS[:description]} * COALESCE(c.d_dist, 10000)
          + #{WEIGHTS[:organisation]} * COALESCE(c.o_dist, 10000)
          + #{WEIGHTS[:state]} * COALESCE(c.s_dist, 10000)
        ) AS weighted_score
      FROM tenders t
      JOIN candidates_scored c ON t.id = c.id
      WHERE t.is_visible = true
      ORDER BY
        (CASE WHEN t.submission_close_date > NOW() THEN 0 ELSE 1 END) ASC,
        weighted_score ASC,
        t.id ASC
      LIMIT #{limit}
    SQL

    results = ActiveRecord::Base.connection.execute(sql)
    ids = results.map { |r| r['id'] }

    # Return snapshot with IDs and total count
    { ids: ids, total: ids.size }
  end

  # Compute MLT ranking
  # OPTIMIZATION: "Global KNN Aggregation" for MLT
  def compute_mlt_ranking(query_text, exclude_id, limit:)
    sanitized_query = ActiveRecord::Base.connection.quote(query_text)
    
    # We fetch enough candidates to find good matches
    sub_limit = [limit * 10, 500].max

    sql = <<-SQL
      WITH q AS (
        SELECT
          to_bm25query(#{sanitized_query}, 'idx_tenders_title_bm25') AS qt,
          to_bm25query(#{sanitized_query}, 'idx_tenders_description_bm25') AS qd
      ),
      candidates_raw AS (
        (
          SELECT id, (title <@> q.qt) as t_dist, NULL::float as d_dist
          FROM tenders t, q
          WHERE t.id <> #{exclude_id.to_i}
          ORDER BY t.title <@> q.qt ASC
          LIMIT #{sub_limit}
        )
        UNION ALL
        (
          SELECT id, NULL::float, (description <@> q.qd)
          FROM tenders t, q
          WHERE t.id <> #{exclude_id.to_i}
          ORDER BY t.description <@> q.qd ASC
          LIMIT #{sub_limit}
        )
      ),
      candidates_scored AS (
        SELECT
          id,
          MIN(t_dist) as t_dist,
          MIN(d_dist) as d_dist
        FROM candidates_raw
        GROUP BY id
      )
      SELECT
        t.id,
        (
            #{WEIGHTS[:title]} * COALESCE(c.t_dist, 10000)
          + #{WEIGHTS[:description]} * COALESCE(c.d_dist, 10000)
        ) AS weighted_score
      FROM tenders t
      JOIN candidates_scored c ON t.id = c.id
      WHERE t.is_visible = true
      ORDER BY
        (CASE WHEN t.submission_close_date > NOW() THEN 0 ELSE 1 END) ASC,
        weighted_score ASC,
        t.id ASC
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