# frozen_string_literal: true

module TenderSearch
  extend self

  SNAPSHOT_TTL = 120.seconds  # 2 minutes
  MAX_SNAPSHOT_SIZE = 200     # Max ranked results to cache

  # Active tender boost (10x score boost for active tenders)
  ACTIVE_BOOST = 1000.0

  # ─────────────────────────────────────────────────────────────────────────────
  # PHASE 1: Search with Snapshot
  # ─────────────────────────────────────────────────────────────────────────────

  def weighted_search(query, page = 1, per_page: 5)
    page = [page.to_i, 1].max
    query = query.to_s.squish

    return [Pagy.new(count: 0, page: 1, items: per_page), []] if query.blank?

    raw_limit = page * per_page
    needed_limit = (raw_limit / 200.0).ceil * 200
    effective_limit = [needed_limit, MAX_SNAPSHOT_SIZE].max

    snapshot = get_or_create_snapshot(query, limit: effective_limit)

    from_pos = ((page - 1) * per_page) + 1
    page_ids = snapshot[:ids].slice((from_pos - 1), per_page) || []

    pagy = Pagy.new(count: snapshot[:total], page: page, items: per_page)
    records = fetch_tenders_in_order(page_ids)

    [pagy, records]
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # PHASE 2: Similar Tenders (MLT) with Snapshot
  # ─────────────────────────────────────────────────────────────────────────────

  def similar_tenders(source_tender, exclude_id, limit: 10)
    return [] if source_tender.nil?

    query_text = if source_tender.title.to_s.match?(/^[A-Z0-9\-\/]+$/)
      source_tender.description
    else
      source_tender.title
    end

    return [] if query_text.blank?

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
  # PHASE 3: Count Matching Tenders
  # ─────────────────────────────────────────────────────────────────────────────

  def count_matching(query, since: nil)
    sanitized = ActiveRecord::Base.connection.quote(query)

    since_clause = if since
      "AND created_at > #{ActiveRecord::Base.connection.quote(since.utc)}"
    else
      ""
    end

    sql = <<-SQL
      SELECT COUNT(*) AS count
      FROM tenders
      WHERE is_visible = true
        #{since_clause}
        AND search_content ||| #{sanitized}
    SQL

    ActiveRecord::Base.connection.execute(sql).first['count'].to_i
  end

  private

  # ─────────────────────────────────────────────────────────────────────────────
  # Snapshot Management
  # ─────────────────────────────────────────────────────────────────────────────

  def get_or_create_snapshot(query, limit: MAX_SNAPSHOT_SIZE)
    cache_key = "search:#{Digest::MD5.hexdigest(query)}:#{limit}"

    Rails.cache.fetch(cache_key, expires_in: SNAPSHOT_TTL) do
      compute_ranking_snapshot(query, limit: limit)
    end
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # ParadeDB BM25 Search - SINGLE QUERY with Boosting
  # ─────────────────────────────────────────────────────────────────────────────
  #
  # OPTIMIZATION: Single query with massive boost for active tenders.
  # This allows ParadeDB to use TopNScanExecState (sub-100ms) instead of
  # breaking optimization with UNION ALL.
  #
  # Strategy:
  #   - Use pdb.score(id) for BM25 relevance
  #   - Add massive constant boost (1000) for active tenders
  #   - Final score = BM25 + (is_active ? 1000 : 0)
  #   - ORDER BY final_score DESC puts active first
  #
  def compute_ranking_snapshot(query, limit:)
    sanitized = ActiveRecord::Base.connection.quote(query)

    # Single query - ParadeDB can optimize this with TopN
    sql = <<-SQL
      SELECT id
      FROM tenders
      WHERE is_visible = true
        AND search_content ||| #{sanitized}
      ORDER BY
        (pdb.score(id) + CASE WHEN is_active = true THEN #{ACTIVE_BOOST} ELSE 0 END) DESC,
        id ASC
      LIMIT #{limit}
    SQL

    results = ActiveRecord::Base.connection.execute(sql)
    ids = results.map { |r| r['id'] }

    { ids: ids, total: ids.size }
  end

  # MLT using single ParadeDB query with boost
  def compute_mlt_ranking(query_text, exclude_id, limit:)
    sanitized = ActiveRecord::Base.connection.quote(query_text)
    excluded = exclude_id.to_i

    sql = <<-SQL
      SELECT id
      FROM tenders
      WHERE is_visible = true
        AND id <> #{excluded}
        AND search_content ||| #{sanitized}
      ORDER BY
        (pdb.score(id) + CASE WHEN is_active = true THEN #{ACTIVE_BOOST} ELSE 0 END) DESC,
        id ASC
      LIMIT #{limit.to_i}
    SQL

    results = ActiveRecord::Base.connection.execute(sql)
    results.map { |r| r['id'] }
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Utilities
  # ─────────────────────────────────────────────────────────────────────────────

  def fetch_tenders_in_order(ids)
    return [] if ids.blank?

    Tender.where(id: ids).index_by(&:id).values_at(*ids).compact
  end
end