# frozen_string_literal: true

module TenderSearch
  extend self

  SNAPSHOT_TTL = 120.seconds  # 2 minutes
  MAX_SNAPSHOT_SIZE = 200     # Max ranked results to cache

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
  # ParadeDB BM25 Search - Pure TopN + Ruby Sort
  # ─────────────────────────────────────────────────────────────────────────────
  #
  # ParadeDB TopN ONLY works when ORDER BY uses indexed fields directly.
  # Expressions like (submission_close_date > NOW()) break TopN.
  #
  # Strategy:
  #   1. Query with pure ORDER BY pdb.score(id) DESC → TopN optimized
  #   2. Fetch 2x results to have enough active+inactive candidates
  #   3. Sort in Ruby to put active first (instant on 400 rows)
  #
  def compute_ranking_snapshot(query, limit:)
    sanitized = ActiveRecord::Base.connection.quote(query)
    fetch_limit = limit * 2  # Fetch extra for active/inactive balancing

    # Pure TopN query - no expressions in ORDER BY
    sql = <<-SQL
      SELECT id, pdb.score(id) AS score, submission_close_date
      FROM tenders
      WHERE is_visible = true
        AND search_content ||| #{sanitized}
      ORDER BY score DESC, id ASC
      LIMIT #{fetch_limit}
    SQL

    results = ActiveRecord::Base.connection.execute(sql)
    now = Time.current

    # Sort in Ruby: active first, then by score (descending)
    sorted = results.to_a.sort_by do |r|
      close_date = r['submission_close_date']
      is_active = close_date.present? && Time.parse(close_date.to_s) > now rescue false
      [
        is_active ? 0 : 1,           # Active first
        -(r['score'].to_f),          # Higher score first
        r['id'].to_i                 # Tiebreaker
      ]
    end

    ids = sorted.take(limit).map { |r| r['id'] }
    { ids: ids, total: ids.size }
  end

  # MLT using pure TopN + Ruby sort
  def compute_mlt_ranking(query_text, exclude_id, limit:)
    sanitized = ActiveRecord::Base.connection.quote(query_text)
    excluded = exclude_id.to_i
    fetch_limit = limit * 3

    sql = <<-SQL
      SELECT id, pdb.score(id) AS score, submission_close_date
      FROM tenders
      WHERE is_visible = true
        AND id <> #{excluded}
        AND search_content ||| #{sanitized}
      ORDER BY score DESC, id ASC
      LIMIT #{fetch_limit}
    SQL

    results = ActiveRecord::Base.connection.execute(sql)
    now = Time.current

    sorted = results.to_a.sort_by do |r|
      close_date = r['submission_close_date']
      is_active = close_date.present? && Time.parse(close_date.to_s) > now rescue false
      [is_active ? 0 : 1, -(r['score'].to_f), r['id'].to_i]
    end

    sorted.take(limit).map { |r| r['id'] }
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Utilities
  # ─────────────────────────────────────────────────────────────────────────────

  def fetch_tenders_in_order(ids)
    return [] if ids.blank?

    Tender.where(id: ids).index_by(&:id).values_at(*ids).compact
  end
end