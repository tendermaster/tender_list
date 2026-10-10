class ApplicationController < ActionController::Base
  include Pagy::Backend
  helper_method :site_base_url
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from Pagy::OverflowError, with: :record_not_found
  # TODO: fix csrf for api
  # protect_from_forgery with: :null_session

  def site_base_url
    Rails.application.config.try(:site_url).presence || request.base_url || 'https://sigmatenders.com'
  end

  private

  def after_sign_in_path_for(resource)
    return stored_location_for(resource) || madmin_root_path if resource.is_a?(AdminUser)

    stored_location_for(resource) || queries_path
  end

  def record_not_found
    render 'home/page_404', status: 404
  end

  def set_public_cache(browser_ttl: 15.minutes, cdn_ttl: 2.hours)
    if current_user.nil?
      # Don't create a session (and Set-Cookie) for cookie-less visitors, mostly
      # crawlers: it filled Redis with millions of sessions and stops CDN caching.
      request.session_options[:skip] = true unless cookies.key?(Rails.application.config.session_options[:key])
      expires_in browser_ttl, public: true, 's-maxage': cdn_ttl
    else
      response.headers['Cache-Control'] = 'no-cache, no-store, private, max-age=0'
    end
  end
end
