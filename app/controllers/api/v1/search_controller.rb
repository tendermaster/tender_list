# frozen_string_literal: true

module Api
  module V1
    class SearchController < ActionController::API
      DEFAULT_PER_PAGE = 10
      MAX_PER_PAGE = 20
      MAX_PAGE = 100
      THROTTLE_LIMIT = 60
      THROTTLE_WINDOW = 1.minute
      # Search loads only what result cards show (TenderSearch::CARD_COLUMNS);
      # the API also returns the value, EMD and tender id
      COLUMNS = %i[id slug_uuid title description organisation state submission_open_date
                   submission_close_date tender_value emd tender_id].freeze

      before_action :authenticate_api_key!
      before_action :throttle_requests!

      def index
        query = params[:q].to_s.squish
        return render_bad_request('q is required') if query.blank?

        page = normalize_page(params[:page])
        per_page = normalize_per_page(params[:per_page])

        pagy, records = TenderSearch.weighted_search(query, page, per_page: per_page)
        ids = records.map(&:id)
        records = Tender.where(id: ids).select(COLUMNS).index_by(&:id).values_at(*ids).compact

        Rails.logger.info(
          "api.v1.search q=#{query.inspect} ip=#{request.remote_ip} page=#{page} per_page=#{per_page} total=#{pagy.count}"
        )

        render json: {
          query: query,
          page: pagy.page,
          per_page: pagy.items,
          total_count: pagy.count,
          total_pages: pagy.pages,
          results: records.map { |tender| serialize_tender(tender) }
        }
      end

      private

      def serialize_tender(tender)
        {
          slug_uuid: tender.slug_uuid,
          title: tender.title,
          description: tender.description,
          organisation: tender.organisation,
          state: tender.state,
          submission_open_date: tender.submission_open_date&.iso8601,
          submission_close_date: tender.submission_close_date&.iso8601,
          tender_value: tender.tender_value,
          emd: tender.emd,
          tender_id: tender.tender_id,
          page_url: "#{request.base_url}#{tender_show_path(slug_uuid: tender.slug_uuid)}"
        }
      end

      def normalize_page(value)
        page = value.to_i
        page = 1 if page < 1
        [page, MAX_PAGE].min
      end

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

        render json: { error: 'API key required: send it in the X-Api-Key header. ' \
                              'Contact SigmaTenders to request one.' }, status: :unauthorized
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
