module Madmin
  class UsersController < Madmin::ResourceController
    # Signs this browser in as the user, to see the site as they do. The admin
    # stays signed in to /admin. bypass_sign_in skips Devise's callbacks, so
    # the user's sign-in count and last sign-in time and IP stay theirs.
    def impersonate
      user = User.find(params[:id])
      bypass_sign_in(user, scope: :user)
      Rails.logger.info("[admin] #{current_admin_user.email} logged in as user ##{user.id} #{user.email}")
      redirect_to '/', notice: "Logged in as #{user.email}"
    end
  end
end
