module Madmin
  class AdminUsersController < Madmin::ResourceController
    private

    # Leaving the password fields empty on edit keeps the current password
    # (Devise would otherwise reject the blank values).
    def resource_params
      permitted = super
      if permitted[:password].blank? && permitted[:password_confirmation].blank?
        permitted = permitted.except(:password, :password_confirmation)
      end
      permitted
    end
  end
end
