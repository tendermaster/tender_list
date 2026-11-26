# frozen_string_literal: true

module Api
  module V1
    # Quote requests from products.sigmatenders.com, posted by its server
    # (products-web) with a key that has the `leads` scope. They go through
    # the same flow as this site's forms (LeadRequests: spam filter, captcha,
    # the India rule, admin). The request comes from products-web's container,
    # so it passes on its visitor's IP, country (Cloudflare's CF-IPCountry)
    # and browser headers; only a leads-scoped key is trusted with them.
    #
    # POST /api/v1/leads
    #   category, supplier (slugs), lead: { name, phone, email, company,
    #   quantity, location, needed_by, details }, cf-turnstile-response,
    #   fill_ms, website (honeypot),
    #   visitor: { ip, country, page, headers: {} }
    # 201 { status: "received", id } | 202 { status: "received" } (spam: the
    # same answer, so bots learn nothing) | 422 { errors: { field: [...] } }
    class LeadsController < ActionController::API
      include ApiKeyAuthentication
      include Captcha
      include LeadRequests

      LEAD_FIELDS = %i[name phone email company quantity location needed_by details].freeze

      before_action -> { authenticate_api_key!('leads') }
      before_action :require_visitor_ip

      def create
        product = Product.in_marketplace.find_by(slug: params[:category].to_s)
        supplier = Supplier.visible.find_by(slug: params[:supplier].to_s) if params[:supplier].present?
        lead = build_lead(params.fetch(:lead, {}).permit(*LEAD_FIELDS).merge(kind: 'quote', product:, supplier:))

        case save_lead(lead)
        when true then render json: { status: 'received', id: lead.id }, status: :created
        when :spam then render json: { status: 'received' }, status: :accepted
        else render json: { errors: lead.errors.to_hash(true) }, status: :unprocessable_content
        end
      end

      private

      # Visitors aren't signed in here
      def current_user = nil

      def visitor = params.fetch(:visitor, {})

      def lead_client_ip = @visitor_ip

      def captcha_remote_ip = @visitor_ip

      def captcha_failure = Captcha.turnstile? ? super : 'captcha not configured'

      # No next page to fire the GA4 event on; products-web reports it
      def note_lead_event(_lead) = nil

      def require_visitor_ip
        @visitor_ip = IPAddr.new(visitor[:ip].to_s).to_s
      rescue IPAddr::Error
        render json: { errors: { visitor: ['ip is required'] } }, status: :unprocessable_content
      end

      # As LeadRequests#request_meta, with the visitor's details from
      # products-web instead of this request's
      def request_meta
        headers = visitor.fetch(:headers, {}).permit!.to_h.filter_map do |name, value|
          name = name.to_s.downcase
          [name, value.to_s.first(500)] unless SECRET_HEADERS.include?(name)
        end.sort.first(60).to_h
        {
          'ip' => @visitor_ip,
          'country' => visitor[:country].to_s.upcase.first(2).presence,
          'page' => visitor[:page].to_s.first(300).presence,
          'site' => 'products.sigmatenders.com',
          'headers' => headers
        }.compact
      end
    end
  end
end
