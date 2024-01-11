class AdminController < ApplicationController
  before_action :authenticate_admin_user!

  def admin2
  end

  def login_as
    if params.require(:user_id)
      user_id = params['user_id'].to_i
      user = User.find(user_id)
      if user
        sign_in(:user, user)
        redirect_to admin2_path
      end
    end
  end

end
