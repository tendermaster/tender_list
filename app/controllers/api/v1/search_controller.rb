# frozen_string_literal: true

module Api
  module V1
    class SearchController < ActionController::API
      DEFAULT_PER_PAGE = 10
      MAX_PER_PAGE = 20
      MAX_PAGE = 100
      THROTTLE_LIMIT = 60
      THROTTLE_WINDOW = 1.minute

      before_action :throttle_requests!

      def index
        query = params[:q].to_s.squish
        return render_bad_request('q is required') if query.blank?

        page = normalize_page(params[:page])
        per_page = normalize_per_page(params[:per_page])

        pagy, records = TenderSearch.weighted_search(query, page, per_page: per_page)

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

      def debug_ip
        render json: {
          remote_ip: request.remote_ip,
          ip: request.ip,
          remote_addr: request.env['REMOTE_ADDR'],
          cf_connecting_ip: request.headers['CF-Connecting-IP'],
          x_forwarded_for: request.headers['X-Forwarded-For'],
          x_real_ip: request.headers['X-Real-IP'],
          forwarded: request.headers['Forwarded'],
          user_agent: request.user_agent
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

      def throttle_requests!
        cache_key = "throttle:api:v1:search:#{request.remote_ip}"
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
