class ApplicationController < ActionController::Base
  include Pagy::Backend
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from Pagy::OverflowError, with: :record_not_found
  # TODO: fix csrf for api
  # protect_from_forgery with: :null_session

  private
  def after_sign_in_path_for(users)
    queries_path
  end

  def record_not_found
    render 'home/page_404', status: 404
  end


end
