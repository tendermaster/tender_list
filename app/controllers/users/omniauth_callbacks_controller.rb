# Google's redirect sign-in flow (/users/auth/google_oauth2). Pages use Google
# Identity Services first (Users::GoogleSignInsController); this is the
# fallback when its script doesn't load.
class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    auth = request.env['omniauth.auth']
    user = User.from_google(uid: auth.uid, email: auth.info.email,
                            email_verified: auth.extra.id_info&.fetch('email_verified', false),
                            name: auth.info.name)

    if user.nil?
      redirect_to new_user_session_path, alert: 'Google has not verified this email address yet.'
    elsif !user.active_for_authentication?
      redirect_to new_user_session_path, alert: I18n.t("devise.failure.#{user.inactive_message}")
    else
      flash[:notice] = I18n.t 'devise.omniauth_callbacks.success', kind: 'Google'
      user.remember_me = true
      sign_in_and_redirect user, event: :authentication
    end
  end
end
