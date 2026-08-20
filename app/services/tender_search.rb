# frozen_string_literal: true

require 'digest/md5'

module TenderSearch
  extend self

  SNAPSHOT_TTL = 30.minutes   # 30 minutes for search ranking snapshot
  HYDRATED_RECORDS_TTL = 15.minutes
  COUNT_TTL = 1.hour
  MLT_TTL = 12.hours          # 12 hours for similar tenders
  MAX_PAGE = 2000             # Support deep pagination (ES handles this well)
  ES_INDEX = 'tenders'
  
  # Tiered cache limits for performance
  CACHE_TIERS = {
    40  => 200,    # Pages 1-40:    fetch 200 ids
    200 => 1000,   # Pages 41-200:  fetch 1000 ids
    500 => 2500,   # Pages 201-500: fetch 2500 ids
    2000 => 5000   # Pages 501-2000: fetch 5000 ids
  }.freeze

  AUTOCOMPLETE_TTL = 10.minutes  # 10 minutes for autocomplete cache

  # ─────────────────────────────────────────────────────────────────────────────
  # Autocomplete Suggestions
  # ─────────────────────────────────────────────────────────────────────────────

  def autocomplete(query, limit: 8)
    query = query.to_s.strip
    return [] if query.blank? || query.length < 2

    cache_key = "autocomplete:#{Digest::MD5.hexdigest(query)}:#{limit}"

    Rails.cache.fetch(cache_key, expires_in: AUTOCOMPLETE_TTL) do
      compute_autocomplete(query, limit: limit)
    end
  rescue StandardError => e
    Rails.logger.error("TenderSearch.autocomplete failed: #{e.message}")
    []
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # PHASE 1: Search with Snapshot
  # ─────────────────────────────────────────────────────────────────────────────

  def weighted_search(query, page = 1, per_page: 5)
    page = [[page.to_i, 1].max, MAX_PAGE].min
    query = query.to_s.squish

    return [Pagy.new(count: 0, page: 1, items: per_page), []] if query.blank?

    effective_limit = CACHE_TIERS.find { |max_page, _| page <= max_page }&.last || 10000
    snapshot = get_or_create_snapshot(query, limit: effective_limit)

    from_pos = ((page - 1) * per_page) + 1
    page_ids = snapshot[:ids].slice((from_pos - 1), per_page) || []

    # Show full page count (up to 2000 pages = 10000 results at 5/page)
    max_results = MAX_PAGE * per_page
    total = [snapshot[:total], max_results].min
    pagy = Pagy.new(count: total, page: page, items: per_page)
    records = fetch_tenders_in_order(page_ids)

    [pagy, records]
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # PHASE 2: Similar Tenders (MLT)
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

    ids = Rails.cache.fetch(cache_key, expires_in: MLT_TTL) do
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
    since_key = since ? since.utc.to_i : 'all'
    cache_key = "search_count:#{Digest::MD5.hexdigest(query.to_s.squish)}:#{since_key}"

    Rails.cache.fetch(cache_key, expires_in: COUNT_TTL) do
      body = {
        query: {
          bool: {
            must: [
              { multi_match: { query: query, fields: ['title', 'description'] } }
            ],
            filter: [
              { term: { is_visible: true } }
            ]
          }
        }
      }

      if since
        body[:query][:bool][:filter] << { range: { updated_at_auto: { gte: since.utc.iso8601 } } }
      end

      result = ElasticClient.count(index: ES_INDEX, body: body)
      result['count'].to_i
    end
  rescue StandardError => e
    Rails.logger.error("TenderSearch.count_matching failed: #{e.message}")
    0
  end

  private

  # ─────────────────────────────────────────────────────────────────────────────
  # Snapshot Management
  # ─────────────────────────────────────────────────────────────────────────────

  def get_or_create_snapshot(query, limit:)
    cache_key = "search:#{Digest::MD5.hexdigest(query)}:#{limit}"

    cached = Rails.cache.read(cache_key)
    return cached if cached.is_a?(Hash) && cached[:ids].present?

    snapshot = compute_ranking_snapshot(query, limit: limit)
    Rails.cache.write(cache_key, snapshot, expires_in: SNAPSHOT_TTL) if snapshot[:ids].present?
    snapshot
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Elasticsearch Search with Active-First Boost
  # ─────────────────────────────────────────────────────────────────────────────
  #
  # Uses function_score with script_score to boost active tenders.
  # Active tenders (submission_close_date > now) get +10000 score boost.
  #
  def compute_ranking_snapshot(query, limit:)
    body = {
      query: {
        function_score: {
          query: {
            bool: {
              must: [
                {
                  multi_match: {
                    query: query,
                    fields: ['title^3', 'tender_id^2', 'description^2', 'organisation^1.5', 'page_link', 'state'],
                    type: 'best_fields'
                  }
                }
              ],
              filter: [
                { term: { is_visible: true } }
              ]
            }
          },
          functions: [
            {
              filter: { range: { submission_close_date: { gt: 'now' } } },
              weight: 10000
            }
          ],
          score_mode: 'sum',
          boost_mode: 'sum'
        }
      },
      size: limit,
      _source: false,
      fields: ['id']
    }

    results = ElasticClient.search(index: ES_INDEX, body: body)
    
    ids = results['hits']['hits'].map { |hit| hit['fields']['id'].first }
    total = results['hits']['total']['value']

    { ids: ids, total: total }
  rescue StandardError => e
    Rails.logger.error("TenderSearch.compute_ranking_snapshot failed: #{e.message}")
    { ids: [], total: 0 }
  end

  # MLT using Elasticsearch more_like_this
  def compute_mlt_ranking(query_text, exclude_id, limit:)
    body = {
      query: {
        function_score: {
          query: {
            bool: {
              must: [
                {
                  more_like_this: {
                    fields: ['title', 'description', 'short_blog'],
                    like: query_text,
                    min_term_freq: 1,
                    max_query_terms: 25
                  }
                }
              ],
              must_not: [
                { term: { id: exclude_id } }
              ],
              filter: [
                { term: { is_visible: true } }
              ]
            }
          },
          functions: [
            {
              filter: { range: { submission_close_date: { gt: 'now' } } },
              weight: 10000
            }
          ],
          score_mode: 'sum',
          boost_mode: 'sum'
        }
      },
      size: limit,
      _source: false,
      fields: ['id']
    }

    results = ElasticClient.search(index: ES_INDEX, body: body)
    results['hits']['hits'].map { |hit| hit['fields']['id'].first }
  rescue StandardError => e
    Rails.logger.error("TenderSearch.compute_mlt_ranking failed: #{e.message}")
    []
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Utilities
  # ─────────────────────────────────────────────────────────────────────────────

  def compute_autocomplete(query, limit:)
    body = {
      query: {
        function_score: {
          query: {
            bool: {
              must: [
                {
                  multi_match: {
                    query: query,
                    type: 'phrase_prefix',
                    fields: ['title^3', 'tender_id^2', 'organisation^1.5', 'description', 'state']
                  }
                }
              ],
              filter: [
                { term: { is_visible: true } }
              ]
            }
          },
          functions: [
            {
              filter: { range: { submission_close_date: { gt: 'now' } } },
              weight: 10000
            }
          ],
          score_mode: 'sum',
          boost_mode: 'sum'
        }
      },
      size: limit,
      _source: ['id', 'title', 'organisation', 'state', 'slug_uuid', 'submission_close_date']
    }

    results = ElasticClient.search(index: ES_INDEX, body: body)
    results['hits']['hits'].map do |hit|
      source = hit['_source']
      source['is_active'] = source['submission_close_date'].present? && 
                            Time.parse(source['submission_close_date']) > Time.current
      source
    end
  end

  def fetch_tenders_in_order(ids)
    return [] if ids.blank?

    cache_key = "tenders:hydrated:#{Digest::MD5.hexdigest(ids.join(','))}"

    Rails.cache.fetch(cache_key, expires_in: HYDRATED_RECORDS_TTL) do
      Tender.where(id: ids).index_by(&:id).values_at(*ids).compact
    end
  end
end
