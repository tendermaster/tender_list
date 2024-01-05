class ApplicationController < ActionController::Base
  include Pagy::Backend
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from Pagy::OverflowError, with: :record_not_found
  # TODO: fix csrf for api
  # protect_from_forgery with: :null_session

  private

  def after_sign_in_path_for(resource)
    # https://stackoverflow.com/questions/15944159/devise-redirect-back-to-the-original-location-after-sign-in-or-sign-up
    # https://github.com/heartcombo/devise/wiki/How-To:-redirect-to-a-specific-page-on-successful-sign-in
    #
    stored_location_for(resource) || queries_path
  end

  def record_not_found
    render 'home/page_404', status: 404
  end

end
