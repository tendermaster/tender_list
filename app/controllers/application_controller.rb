class ApplicationController < ActionController::Base
  include Pagy::Backend
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from Pagy::OverflowError, with: :record_not_found
  # TODO: fix csrf for api
  # protect_from_forgery with: :null_session

  private

  def after_sign_in_path_for(resource)
    stored_location_for(resource) || queries_path
  end

  def record_not_found
    render 'home/page_404', status: 404
  end

  def set_public_cache(browser_ttl: 15.minutes, cdn_ttl: 2.hours)
    if current_user.nil?
      expires_in browser_ttl, public: true, 's-maxage': cdn_ttl
    else
      response.headers['Cache-Control'] = 'no-cache, no-store, private, max-age=0'
    end
  end
end
