# frozen_string_literal: true

require 'digest/md5'

module TenderSearch
  extend self

  class SearchUnavailableError < StandardError; end

  SNAPSHOT_TTL = 3.hours      # 3 hours for search ranking snapshot (absorbs bot traffic)
  HYDRATED_RECORDS_TTL = 15.minutes
  COUNT_TTL = 1.hour
  MLT_TTL = 3.days            # similar tenders rarely change; MLT queries are expensive
  PER_PAGE = 10
  # Deeper pages were nearly all crawlers, and page 1,800 made Elasticsearch
  # rank 5,000 tenders to show 5
  MAX_PAGE = 50
  ES_INDEX = 'tenders'

  # Ids fetched per snapshot: most visits stop in the first pages
  CACHE_TIERS = {
    20 => 200,   # Pages 1-20
    50 => 500    # Pages 21-50
  }.freeze

  SORTS = %w[relevance closing newest].freeze

  # Search filters from request params: open tenders only, a state, the order
  def filters_from(params)
    sort = SORTS.include?(params[:sort].to_s) ? params[:sort].to_s : 'relevance'
    {
      open: params[:status].to_s == 'open' || sort == 'closing',
      closed: params[:status].to_s == 'closed' && sort != 'closing',
      state: params[:state].presence&.to_s&.squish&.slice(0, 60),
      sort: sort
    }
  end

  def filtered?(filters) = filters[:open] || filters[:closed] || filters[:state].present? || filters[:sort] != 'relevance'

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

  def weighted_search(query, page = 1, per_page: PER_PAGE, filters: {})
    page = [[page.to_i, 1].max, MAX_PAGE].min
    query = query.to_s.squish
    filters = { open: false, state: nil, sort: 'relevance' }.merge(filters)

    return [Pagy.new(count: 0, page: 1, items: per_page), [], false] if query.blank?

    Telemetry::Tracer.in_span('tender_search.weighted_search', { 'search.query' => query, 'search.page' => page, 'search.per_page' => per_page }) do
      last_row = page * per_page
      effective_limit = CACHE_TIERS.values.find { |ids| ids >= last_row } || last_row
      snapshot = get_or_create_snapshot(query, limit: effective_limit, filters: filters)

      from_pos = ((page - 1) * per_page) + 1
      page_ids = snapshot[:ids].slice((from_pos - 1), per_page) || []

      # Page numbers stop at MAX_PAGE; the 4th value is the full count
      # (counted up to 10,000)
      pagy = Pagy.new(count: [snapshot[:total], MAX_PAGE * per_page].min, page: page, items: per_page)
      records = fetch_tenders_in_order(page_ids)

      [pagy, records, snapshot[:cache_hit], snapshot[:total]]
    end
  end

  # Whether a results page has any results. Crawlers ask for page 20 of
  # searches with one page of results; this answers from a cached snapshot or
  # a cached count instead of ranking hundreds of tenders to find nothing.
  def page_exists?(query, page, per_page: PER_PAGE, filters: {})
    page = page.to_i
    return true if page <= 1

    filters = { open: false, state: nil, sort: 'relevance' }.merge(filters)
    query = query.to_s.squish
    return false if query.blank?

    total_matching(query, filters) > (page - 1) * per_page
  end

  # How many visible tenders match (counted up to 10,000), with filters
  def matching_count(query, filters: {})
    total_matching(query.to_s.squish, { open: false, state: nil, sort: 'relevance' }.merge(filters))
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
            must: [search_clause_for(query)],
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

  OPEN = { range: { submission_close_date: { gt: 'now/m' } } }.freeze
  CLOSED = { range: { submission_close_date: { lte: 'now/m' } } }.freeze

  def filter_clauses(filters)
    clauses = [{ term: { is_visible: true } }]
    clauses << OPEN if filters[:open]
    clauses << CLOSED if filters[:closed]
    clauses << { match: { state: { query: filters[:state], operator: 'and' } } } if filters[:state].present?
    clauses
  end

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
                                              default_operator: 'and' } }]
        }
      }
    end

    # Saved searches: "(solar panel) | (street light)". | is OR; the words
    # inside a group must all match.
    if clean_query.match?(/[|()]/)
      { simple_query_string: { query: clean_query, fields: TEXT_FIELDS, default_operator: 'and' } }
    else
      words_clause(clean_query)
    end
  end

  # Where words are looked for, and how much a match in each counts
  TEXT_FIELDS = ['title^3', 'organisation^1.5', 'description', 'state', 'tender_category'].freeze

  # Typed words: most of them must appear (all of up to 3; 75% of longer
  # queries), anywhere across the fields, so "road construction pwd" finds
  # a PWD road tender; matching any one word made "empanelment of agency"
  # match every tender with "of", slowly. The exact phrase in the title ranks
  # higher, and a tender id finds that tender.
  def words_clause(text)
    {
      bool: {
        should: [
          { multi_match: { query: text, type: 'cross_fields', fields: TEXT_FIELDS, minimum_should_match: '3<75%' } },
          { match_phrase: { title: { query: text, boost: 2 } } },
          { term: { 'tender_id.keyword' => { value: text, boost: 20 } } }
        ],
        minimum_should_match: 1
      }
    }
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Snapshot Management
  # ─────────────────────────────────────────────────────────────────────────────

  # closed only when set, so cached searches from before it existed keep their keys
  def snapshot_hash(query, filters)
    Digest::MD5.hexdigest([query, filters[:open], filters[:state], filters[:sort], *('closed' if filters[:closed])].join("\u0000"))
  end

  # Matching tenders (up to 10,000, as search counts them), from any cached
  # snapshot of the search, else an Elasticsearch count
  def total_matching(query, filters)
    query_hash = snapshot_hash(query, filters)
    cached = CACHE_TIERS.values.lazy.map { |limit| Rails.cache.read("search:#{query_hash}:#{limit}") }.find { |snapshot| snapshot.is_a?(Hash) }
    return cached[:total].to_i if cached

    Rails.cache.fetch("search_total:#{query_hash}", expires_in: COUNT_TTL) do
      body = { query: { bool: { must: [search_clause_for(query)], filter: filter_clauses(filters) } } }
      [ElasticClient.count(index: ES_INDEX, body: body)['count'].to_i, 10_000].min
    end
  end

  def get_or_create_snapshot(query, limit:, filters:)
    query_hash = snapshot_hash(query, filters)
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
    snapshot = compute_ranking_snapshot(query, limit: limit, filters: filters)

    Rails.cache.write(target_cache_key, snapshot, expires_in: SNAPSHOT_TTL) if snapshot[:ids].present?
    snapshot.merge(cache_hit: false)
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Elasticsearch Search with Active-First Boost
  # ─────────────────────────────────────────────────────────────────────────────
  #
  # Uses function_score with script_score to boost active tenders.
  # Active tenders (submission_close_date > now) get +10000 score boost.
  #
  def compute_ranking_snapshot(query, limit:, filters:)
    Telemetry::Tracer.in_span('tender_search.compute_ranking_snapshot', { 'search.query' => query, 'search.limit' => limit }) do
      matching = { bool: { must: [search_clause_for(query)], filter: filter_clauses(filters) } }
      body = {
        size: limit,
        track_total_hits: 10000,
        _source: false,
        fields: ['id']
      }
      case filters[:sort]
      when 'closing'
        body.merge!(query: matching, sort: [{ submission_close_date: 'asc' }, '_score'])
      when 'newest'
        body.merge!(query: matching, sort: [{ id: 'desc' }])
      else
        # Open tenders first, each group by relevance
        body[:query] = {
          function_score: {
            query: matching,
            functions: [{ filter: OPEN, weight: 10000 }],
            score_mode: 'sum',
            boost_mode: 'sum'
          }
        }
      end

      results = ElasticClient.search(index: ES_INDEX, body: body)
      ids = results['hits']['hits'].map { |hit| hit['fields']['id'].first }
      { ids: ids, total: results['hits']['total']['value'] }
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
