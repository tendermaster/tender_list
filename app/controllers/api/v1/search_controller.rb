# frozen_string_literal: true

module Api
  module V1
    class SearchController < ActionController::API
      DEFAULT_PER_PAGE = 10
      MAX_PER_PAGE = 20
      THROTTLE_LIMIT = 60
      THROTTLE_WINDOW = 1.minute
      STATUSES = %w[open closed all].freeze
      # Search loads only what result cards show (TenderSearch::CARD_COLUMNS);
      # the API also returns the value, EMD and tender id
      COLUMNS = %i[id slug_uuid title description organisation state submission_open_date
                   submission_close_date tender_value emd tender_id].freeze

      before_action :authenticate_api_key!
      before_action :throttle_requests!

      def index
        query = params[:q].to_s.squish
        return render_bad_request('q is required') if query.blank?
        return if invalid_filters?

        page = normalize_page(params[:page])
        per_page = normalize_per_page(params[:per_page])
        filters = TenderSearch.filters_from(params)

        # Search pages stop at TenderSearch::MAX_PAGE; a later page is empty
        # rather than a repeat of the last one
        total = TenderSearch.matching_count(query, filters:)
        total_pages = [(total / per_page.to_f).ceil, TenderSearch::MAX_PAGE].min
        records = []
        if page <= total_pages
          _pagy, found = TenderSearch.weighted_search(query, page, per_page:, filters:)
          ids = found.map(&:id)
          records = Tender.where(id: ids).select(COLUMNS).index_by(&:id).values_at(*ids).compact
        end

        Rails.logger.info(
          "api.v1.search q=#{query.inspect} key=#{@api_key.id} page=#{page} per_page=#{per_page} total=#{total}"
        )

        render json: {
          query: query,
          filters: { status: filters[:open] ? 'open' : filters[:closed] ? 'closed' : 'all', state: filters[:state],
                     sort: filters[:sort] },
          page: page,
          per_page: per_page,
          total_count: total,
          total_pages: total_pages,
          results: records.map { |tender| serialize_tender(tender) }
        }
      end

      private

      IST = ActiveSupport::TimeZone['Asia/Kolkata']

      def serialize_tender(tender)
        closes = ist(tender.submission_close_date)
        {
          slug_uuid: tender.slug_uuid,
          title: tender.title,
          description: tender.description,
          organisation: tender.organisation,
          state: tender.state,
          submission_open_date: ist(tender.submission_open_date)&.iso8601,
          submission_close_date: closes&.iso8601,
          status: closes && (closes > Time.current ? 'open' : 'closed'),
          tender_value: tender.tender_value,
          emd: tender.emd,
          tender_id: tender.tender_id,
          page_url: "#{request.base_url}#{tender_show_path(slug_uuid: tender.slug_uuid)}"
        }
      end

      # Portal dates are stored as IST wall-clock times in a UTC column: give
      # them their real +05:30 offset
      def ist(time) = time && IST.local(time.year, time.month, time.day, time.hour, time.min, time.sec)

      # Unknown values are an error, not silently ignored (status=closed once
      # returned every tender)
      def invalid_filters?
        status = params[:status].presence || 'all'
        sort = params[:sort].presence || 'relevance'
        message = if STATUSES.exclude?(status)
                    "status must be one of: #{STATUSES.join(', ')}"
                  elsif TenderSearch::SORTS.exclude?(sort)
                    "sort must be one of: #{TenderSearch::SORTS.join(', ')}"
                  elsif status == 'closed' && sort == 'closing'
                    'sort=closing lists open tenders, soonest first; use it without status=closed'
                  end
        message && render_bad_request(message)
      end

      def normalize_page(value) = [value.to_i, 1].max

      def normalize_per_page(value)
        per_page = value.to_i
        per_page = DEFAULT_PER_PAGE if per_page < 1
        [per_page, MAX_PER_PAGE].min
      end

      # A partner's key, in X-Api-Key or Authorization: Bearer (ApiKey)
      def authenticate_api_key!
        token = request.headers['X-Api-Key'].presence ||
                request.authorization.to_s[/\ABearer (.+)\z/, 1]
        @api_key = ApiKey.authenticate(token)
        return @api_key.record_use! if @api_key

        error = if token.present?
                  'Invalid or revoked API key. Contact SigmaTenders if you need a new one.'
                else
                  'API key required: send it in the X-Api-Key header. Contact SigmaTenders to request one.'
                end
        render json: { error: }, status: :unauthorized
      end

      def throttle_requests!
        cache_key = "throttle:api:v1:search:key:#{@api_key.id}"
        request_count = Rails.cache.increment(cache_key, 1, expires_in: THROTTLE_WINDOW)

        unless request_count
          Rails.cache.write(cache_key, 1, expires_in: THROTTLE_WINDOW)
          request_count = 1
        end

        return if request_count <= THROTTLE_LIMIT

        render json: { error: 'rate limit exceeded' }, status: :too_many_requests
      end

      def render_bad_request(message)
        render json: { error: message }, status: :bad_request
      end
    end
  end
end
