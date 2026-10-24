class ApplicationController < ActionController::Base
  include Pagy::Backend
  include Captcha
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
    # New users: onboarding first, then back where they were headed
    return welcome_path(return_to: stored_location_for(resource)) if resource.new_to_onboarding?

    stored_location_for(resource) || queries_path
  end

  # Which of these tenders the signed-in user has saved, for their Save buttons
  def bookmarked_ids_for(tenders)
    return Set.new if current_user.nil? || tenders.blank?

    current_user.bookmarks.where(tender_id: tenders.map(&:id)).pluck(:tender_id).to_set
  end

  # Always the HTML page: /blog/robots.txt asked for a text 404 and got a 500
  def record_not_found
    render 'home/page_404', status: 404, formats: :html
  end

  def set_public_cache(cdn_ttl: 2.hours)
    if current_user.nil?
      # Don't create a session (and Set-Cookie) for cookie-less visitors, mostly
      # crawlers: it filled Redis with millions of sessions and stops CDN caching.
      request.session_options[:skip] = true unless cookies.key?(Rails.application.config.session_options[:key])
      # max-age=0: a browser that kept this logged-out copy would keep showing
      # it after the visitor signs in (Google One Tap signs in on any page)
      expires_in 0, public: true, 's-maxage': cdn_ttl
    else
      response.headers['Cache-Control'] = 'no-cache, no-store, private, max-age=0'
    end
  end
end
