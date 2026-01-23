# frozen_string_literal: true

module TenderSearch
  extend self

  SNAPSHOT_TTL = 120.seconds  # 2 minutes
  MAX_PAGE = 100              # Cap pagination at page 100
  
  # Tiered cache limits for performance
  # Pages 1-40:  200 results (~300ms)
  # Pages 41-100: 500 results (~500ms)
  CACHE_TIERS = {
    40 => 200,   # Pages 1-40
    100 => 500   # Pages 41-100
  }.freeze

  # ─────────────────────────────────────────────────────────────────────────────
  # PHASE 1: Search with Snapshot
  # ─────────────────────────────────────────────────────────────────────────────

  def weighted_search(query, page = 1, per_page: 5)
    page = [[page.to_i, 1].max, MAX_PAGE].min  # Clamp to 1..100
    query = query.to_s.squish

    return [Pagy.new(count: 0, page: 1, items: per_page), []] if query.blank?

    # Determine cache tier based on page
    raw_limit = page * per_page
    effective_limit = CACHE_TIERS.find { |max_page, _| page <= max_page }&.last || 500

    snapshot = get_or_create_snapshot(query, limit: effective_limit)

    from_pos = ((page - 1) * per_page) + 1
    page_ids = snapshot[:ids].slice((from_pos - 1), per_page) || []

    # Use effective_limit as total (capped results)
    total = [snapshot[:total], effective_limit].min
    pagy = Pagy.new(count: total, page: page, items: per_page)
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
  # ParadeDB BM25 Search - Subquery Approach
  # ─────────────────────────────────────────────────────────────────────────────
  #
  # Strategy:
  #   1. Inner query: Pure TopN on pdb.score() (ParadeDB optimized, ~280ms)
  #   2. Outer query: Re-sort by active first (instant on ~400 rows)
  #
  def compute_ranking_snapshot(query, limit:)
    sanitized = ActiveRecord::Base.connection.quote(query)
    fetch_limit = limit * 2  # Fetch extra for active/inactive balancing

    sql = <<-SQL
      SELECT id FROM (
        SELECT id, pdb.score(id) AS score, submission_close_date
        FROM tenders
        WHERE is_visible = true
          AND search_content ||| #{sanitized}
        ORDER BY score DESC, id ASC
        LIMIT #{fetch_limit}
      ) t
      ORDER BY (submission_close_date > NOW()) DESC, score DESC, id ASC
      LIMIT #{limit}
    SQL

    results = ActiveRecord::Base.connection.execute(sql)
    ids = results.map { |r| r['id'] }
    { ids: ids, total: ids.size }
  end

  # MLT using subquery approach
  def compute_mlt_ranking(query_text, exclude_id, limit:)
    sanitized = ActiveRecord::Base.connection.quote(query_text)
    excluded = exclude_id.to_i
    fetch_limit = limit * 3

    sql = <<-SQL
      SELECT id FROM (
        SELECT id, pdb.score(id) AS score, submission_close_date
        FROM tenders
        WHERE is_visible = true
          AND id <> #{excluded}
          AND search_content ||| #{sanitized}
        ORDER BY score DESC, id ASC
        LIMIT #{fetch_limit}
      ) t
      ORDER BY (submission_close_date > NOW()) DESC, score DESC, id ASC
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