# frozen_string_literal: true

require 'digest/md5'

module TenderSearch
  extend self

  class SearchUnavailableError < StandardError; end

  SNAPSHOT_TTL = 3.hours      # 3 hours for search ranking snapshot (absorbs bot traffic)
  HYDRATED_RECORDS_TTL = 15.minutes
  COUNT_TTL = 1.hour
  MLT_TTL = 3.days            # similar tenders rarely change; MLT queries are expensive
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

    Telemetry::Tracer.in_span('tender_search.autocomplete', { 'search.query' => query, 'search.limit' => limit }) do
      cache_key = "autocomplete:#{Digest::MD5.hexdigest(query)}:#{limit}"

      Rails.cache.fetch(cache_key, expires_in: AUTOCOMPLETE_TTL) do
        compute_autocomplete(query, limit: limit)
      end
    end
  rescue StandardError => e
    Telemetry::Tracer.record_exception(e)
    Rails.logger.error("TenderSearch.autocomplete failed: #{e.message}")
    []
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # PHASE 1: Search with Snapshot
  # ─────────────────────────────────────────────────────────────────────────────

  def weighted_search(query, page = 1, per_page: 5)
    page = [[page.to_i, 1].max, MAX_PAGE].min
    query = query.to_s.squish

    return [Pagy.new(count: 0, page: 1, items: per_page), [], false] if query.blank?

    Telemetry::Tracer.in_span('tender_search.weighted_search', { 'search.query' => query, 'search.page' => page, 'search.per_page' => per_page }) do
      effective_limit = CACHE_TIERS.find { |max_page, _| page <= max_page }&.last || 10000
      snapshot = get_or_create_snapshot(query, limit: effective_limit)

      from_pos = ((page - 1) * per_page) + 1
      page_ids = snapshot[:ids].slice((from_pos - 1), per_page) || []

      # Show full page count (up to 2000 pages = 10000 results at 5/page)
      max_results = MAX_PAGE * per_page
      total = [snapshot[:total], max_results].min
      pagy = Pagy.new(count: total, page: page, items: per_page)
      records = fetch_tenders_in_order(page_ids)

      [pagy, records, snapshot[:cache_hit]]
    end
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

    Telemetry::Tracer.in_span('tender_search.similar_tenders', { 'tender.id' => exclude_id, 'mlt.limit' => limit }) do
      cache_key = "mlt:#{exclude_id}:#{Digest::MD5.hexdigest(query_text.squish)}"

      cached_ids = Rails.cache.read(cache_key)
      if cached_ids.is_a?(Array) && cached_ids.present?
        return fetch_tenders_in_order(cached_ids)
      end

      ids = compute_mlt_ranking(query_text.squish, exclude_id, limit: limit)
      if ids.present?
        Rails.cache.write(cache_key, ids, expires_in: MLT_TTL)
      end

      fetch_tenders_in_order(ids)
    end
  rescue StandardError => e
    Telemetry::Tracer.record_exception(e)
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
    Telemetry::Tracer.record_exception(e)
    Rails.logger.error("TenderSearch.count_matching failed: #{e.message}")
    0
  end

  # Whether any visible tender matches, using the same matching as search.
  # Stops at the first hit, so it costs milliseconds instead of a ranked search.
  def any_match?(query)
    body = {
      query: {
        bool: {
          must: [search_clause_for(query)],
          filter: [{ term: { is_visible: true } }]
        }
      }
    }
    ElasticClient.count(index: ES_INDEX, body: body, terminate_after: 1)['count'].to_i.positive?
  end

  private

  # "-(term)" / "-term": a tender mentioning it is left out
  EXCLUDED_TERM = /(?:\A|\s)-(\([^)]*\)|[^\s()|]+)/

  def search_clause_for(query)
    # Sanitize empty parentheses from query strings
    clean_query = query.to_s.gsub(/\(\s*\)/, '').gsub(/-\(\s*\)/, '').squish

    # Exclusions go in must_not. Inside the query string, where terms are
    # OR'd, "-(road)" means "or doesn't mention road": nearly every tender
    # matched, so the results were wrong and a saved search with exclusions
    # took 20s+.
    excluded = clean_query.scan(EXCLUDED_TERM).flatten
    included = clean_query.gsub(EXCLUDED_TERM, ' ').squish
    if excluded.any? && included.present?
      return {
        bool: {
          must: [search_clause_for(included)],
          must_not: [{ simple_query_string: { query: excluded.join(' | '), fields: %w[title organisation state],
                                              default_operator: 'or' } }]
        }
      }
    end

    # Determine if query uses Lucene boolean syntax (pipes, negations, or grouping)
    if clean_query.match?(/[|()]|(?:\s-\w+)/)
      {
        simple_query_string: {
          query: clean_query,
          fields: ['title^3', 'organisation^1.5', 'state', 'tender_id.keyword^2'],
          default_operator: 'or'
        }
      }
    else
      {
        multi_match: {
          query: clean_query,
          fields: ['title^3', 'description^2', 'organisation^1.5', 'tender_id.keyword^2', 'page_link', 'state'],
          type: 'best_fields'
        }
      }
    end
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Snapshot Management
  # ─────────────────────────────────────────────────────────────────────────────

  def get_or_create_snapshot(query, limit:)
    query_hash = Digest::MD5.hexdigest(query)
    target_cache_key = "search:#{query_hash}:#{limit}"

    # 1. Exact tier match
    cached = Rails.cache.read(target_cache_key)
    if cached.is_a?(Hash) && cached[:ids].present?
      Telemetry::Metrics.record_cache_event(operation: 'search_snapshot', key: target_cache_key, hit: true)
      return cached.merge(cache_hit: true)
    elsif cached.present?
      Rails.cache.delete(target_cache_key)
    end

    # 2. Superset cache reuse: Check if a higher tier is already cached
    higher_tiers = CACHE_TIERS.values.select { |tier_limit| tier_limit > limit }.sort
    higher_tiers.each do |tier_limit|
      superset_key = "search:#{query_hash}:#{tier_limit}"
      superset_cached = Rails.cache.read(superset_key)
      if superset_cached.is_a?(Hash) && superset_cached[:ids].present? && superset_cached[:ids].size >= limit
        Telemetry::Metrics.record_cache_event(operation: 'search_snapshot_superset', key: superset_key, hit: true)
        sliced_snapshot = {
          ids: superset_cached[:ids].first(limit),
          total: superset_cached[:total],
          cache_hit: true
        }
        Rails.cache.write(target_cache_key, sliced_snapshot.except(:cache_hit), expires_in: SNAPSHOT_TTL)
        return sliced_snapshot
      end
    end

    # 3. Compute from Elasticsearch
    Telemetry::Metrics.record_cache_event(operation: 'search_snapshot', key: target_cache_key, hit: false)
    snapshot = compute_ranking_snapshot(query, limit: limit)

    # Deep pagination queries (limit >= 2500) get 2-hour TTL to absorb crawler spikes
    ttl = limit >= 2500 ? 2.hours : SNAPSHOT_TTL
    Rails.cache.write(target_cache_key, snapshot, expires_in: ttl) if snapshot[:ids].present?
    snapshot.merge(cache_hit: false)
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Elasticsearch Search with Active-First Boost
  # ─────────────────────────────────────────────────────────────────────────────
  #
  # Uses function_score with script_score to boost active tenders.
  # Active tenders (submission_close_date > now) get +10000 score boost.
  #
  def compute_ranking_snapshot(query, limit:)
    Telemetry::Tracer.in_span('tender_search.compute_ranking_snapshot', { 'search.query' => query, 'search.limit' => limit }) do
      search_clause = search_clause_for(query)

      body = {
        query: {
          function_score: {
            query: {
              bool: {
                must: [search_clause],
                filter: [
                  { term: { is_visible: true } }
                ]
              }
            },
            functions: [
              {
                filter: { range: { submission_close_date: { gt: 'now/m' } } },
                weight: 10000
              }
            ],
            score_mode: 'sum',
            boost_mode: 'sum'
          }
        },
        size: limit,
        track_total_hits: 10000,
        _source: false,
        fields: ['id']
      }

      results = ElasticClient.search(index: ES_INDEX, body: body)
      
      ids = results['hits']['hits'].map { |hit| hit['fields']['id'].first }
      total = results['hits']['total']['value']

      { ids: ids, total: total }
    end
  rescue StandardError => e
    Telemetry::Tracer.record_exception(e)
    Rails.logger.error("TenderSearch.compute_ranking_snapshot failed: #{e.message}")
    raise SearchUnavailableError, "Search service temporarily unavailable: #{e.message}"
  end

  # MLT using Elasticsearch more_like_this
  def compute_mlt_ranking(query_text, exclude_id, limit:)
    clean_text = query_text.to_s.squish.slice(0, 400)
    body = {
      query: {
        function_score: {
          query: {
            bool: {
              must: [
                {
                  more_like_this: {
                    fields: ['title', 'organisation'],
                    like: clean_text,
                    min_term_freq: 1,
                    min_doc_freq: 2,
                    # ignore very common terms ("supply", "work", ...): they match
                    # millions of docs and made this query take seconds
                    max_doc_freq: 50_000,
                    max_query_terms: 10
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
              filter: { range: { submission_close_date: { gt: 'now/m' } } },
              weight: 10000
            }
          ],
          score_mode: 'sum',
          boost_mode: 'sum'
        }
      },
      size: limit,
      _source: false,
      fields: ['id'],
      track_total_hits: false,
      timeout: '1s' # partial results are fine for a "similar tenders" widget
    }

    results = ElasticClient.search(index: ES_INDEX, body: body)
    results['hits']['hits'].map { |hit| hit['fields']['id'].first }
  rescue StandardError => e
    Telemetry::Tracer.record_exception(e)
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
                    fields: ['title^3', 'tender_id^2', 'organisation^1.5', 'state'],
                    max_expansions: 10
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
              filter: { range: { submission_close_date: { gt: 'now/m' } } },
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

  CARD_COLUMNS = %i[
    id slug_uuid title description short_blog emd tender_fee 
    organisation submission_open_date submission_close_date state location meta_data
  ].freeze

  def fetch_tenders_in_order(ids)
    return [] if ids.blank?

    Telemetry::Tracer.in_span('tender_search.fetch_tenders_in_order', { 'records.count' => ids.size }) do
      cache_key = "tenders:hydrated:#{Digest::MD5.hexdigest(ids.join(','))}"

      Rails.cache.fetch(cache_key, expires_in: HYDRATED_RECORDS_TTL) do
        Tender.select(CARD_COLUMNS).where(id: ids).index_by(&:id).values_at(*ids).compact
      end
    end
  end
end
