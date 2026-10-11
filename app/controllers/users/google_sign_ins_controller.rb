# POST /users/google_sign_in: signs in with the ID token Google Identity Services
# gives the page (One Tap, or the "Sign in with Google" button), without
# leaving the page. See app/javascript/controllers/google_sign_in_controller.js.
class Users::GoogleSignInsController < ApplicationController
  # Logged-out pages are publicly cached and have no session, so their Rails
  # CSRF token can't be checked. The page instead sets a random g_csrf_token
  # cookie and sends the same value in the body (Google's double-submit
  # scheme): another site can't read or set our cookies.
  skip_forgery_protection
  before_action :verify_double_submit_token

  def create
    claims = GoogleIdToken.verify(params[:credential])
    user = User.from_google(uid: claims['sub'], email: claims['email'],
                            email_verified: claims['email_verified'], name: claims['name'])
    return render(json: { error: 'Google has not verified this email address yet.' }, status: :forbidden) if user.nil?
    unless user.active_for_authentication?
      return render json: { error: I18n.t("devise.failure.#{user.inactive_message}") }, status: :forbidden
    end

    user.remember_me = true
    sign_in(:user, user, event: :authentication)
    # Stay on the page the visitor signed in from; from the sign-in page, go
    # where they were headed
    render json: { redirect: return_to || after_sign_in_path_for(user) }
  rescue GoogleIdToken::InvalidToken => e
    Rails.logger.warn("Google sign-in rejected: #{e.message}")
    render json: { error: 'Google sign-in failed, please try again.' }, status: :unauthorized
  end

  private

  # Only paths on this site, never "//other.site"
  def return_to
    path = params[:return_to].to_s
    path if path.start_with?('/') && !path.start_with?('//')
  end

  def verify_double_submit_token
    cookie = cookies[:g_csrf_token].to_s
    return if cookie.present? && ActiveSupport::SecurityUtils.secure_compare(cookie, params[:g_csrf_token].to_s)

    render json: { error: 'Please reload the page and try again.' }, status: :forbidden
  end
end
