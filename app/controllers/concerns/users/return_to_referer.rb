# Opening the sign-in or sign-up page from a tender remembers the tender, so
# Devise's after_sign_in_path_for brings the user back to it.
module Users::ReturnToReferer
  extend ActiveSupport::Concern

  included do
    before_action :store_referer, only: :new
  end

  private

  def store_referer
    referer = URI.parse(request.referer.to_s)
    return unless referer.host == request.host && !referer.path.start_with?('/users')

    store_location_for(:user, referer.request_uri)
  rescue URI::InvalidURIError
    nil
  end
end
