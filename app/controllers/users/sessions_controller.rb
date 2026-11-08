# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  include Users::ReturnToReferer

  def create
    response = super
    if current_user
      PostHog.identify(
        distinct_id: current_user.posthog_distinct_id,
        properties: current_user.posthog_properties
      )
      PostHog.capture(
        distinct_id: current_user.posthog_distinct_id,
        event: 'user_logged_in',
        properties: { authentication_method: 'email' }
      )
    end
    response
  end

  def destroy
    PostHog.capture(
      distinct_id: current_user.posthog_distinct_id,
      event: 'user_logged_out'
    ) if current_user
    super
    # Google One Tap would sign the user straight back in on the next page;
    # google_sign_in_controller.js turns its auto sign-in off when it sees this
    cookies[:signed_out] = { value: '1', expires: 1.hour, same_site: :lax }
  end
end
