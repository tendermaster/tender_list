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
  MAX_SNAPSHOT_SIZE = 5000    # Max ranked results to cache

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

    # Get or create snapshot
    snapshot = get_or_create_snapshot(query)

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
      SELECT COUNT(*)
      FROM tenders t, q
      WHERE t.is_visible = true
        AND t.submission_close_date > NOW()
        #{since_clause}
        AND (
          t.title <@> q.qt IS NOT NULL
          OR t.description <@> q.qd IS NOT NULL
        )
    SQL

    ActiveRecord::Base.connection.execute(sql).first['count'].to_i
  end

  private

  # ─────────────────────────────────────────────────────────────────────────────
  # Snapshot Management
  # ─────────────────────────────────────────────────────────────────────────────

  def get_or_create_snapshot(query)
    cache_key = "search:#{Digest::MD5.hexdigest(query)}"

    Rails.cache.fetch(cache_key, expires_in: SNAPSHOT_TTL) do
      compute_ranking_snapshot(query)
    end
  end

  # Compute BM25 ranking ONCE and store as snapshot
  def compute_ranking_snapshot(query)
    sanitized_query = ActiveRecord::Base.connection.quote(query)

    sql = <<-SQL
      WITH q AS (
        SELECT
          to_bm25query(#{sanitized_query}, 'idx_tenders_title_bm25') AS qt,
          to_bm25query(#{sanitized_query}, 'idx_tenders_description_bm25') AS qd,
          to_bm25query(#{sanitized_query}, 'idx_tenders_organisation_bm25') AS qo,
          to_bm25query(#{sanitized_query}, 'idx_tenders_state_bm25') AS qs
      ),
      scored AS (
        SELECT
          t.id,
          (
              #{WEIGHTS[:title]} * COALESCE(t.title <@> q.qt, 0)
            + #{WEIGHTS[:description]} * COALESCE(t.description <@> q.qd, 0)
            + #{WEIGHTS[:organisation]} * COALESCE(t.organisation <@> q.qo, 0)
            + #{WEIGHTS[:state]} * COALESCE(t.state <@> q.qs, 0)
          ) AS score,
          CASE
            WHEN t.submission_close_date > NOW() AT TIME ZONE 'Asia/Kolkata' THEN 0
            ELSE 1
          END AS expired_penalty
        FROM tenders t, q
        WHERE t.is_visible = true
          AND (
            t.title <@> q.qt IS NOT NULL
            OR t.description <@> q.qd IS NOT NULL
            OR t.organisation <@> q.qo IS NOT NULL
            OR t.state <@> q.qs IS NOT NULL
          )
      )
      SELECT id
      FROM scored
      ORDER BY expired_penalty ASC, score ASC, id ASC
      LIMIT #{MAX_SNAPSHOT_SIZE}
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
