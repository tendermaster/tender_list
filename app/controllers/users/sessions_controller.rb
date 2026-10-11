# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  include Users::ReturnToReferer

  def destroy
    super
    # Google One Tap would sign the user straight back in on the next page;
    # google_sign_in_controller.js turns its auto sign-in off when it sees this
    cookies[:signed_out] = { value: '1', expires: 1.hour, same_site: :lax }
  end
end
