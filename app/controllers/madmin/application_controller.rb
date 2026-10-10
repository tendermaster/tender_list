module Madmin
  class ApplicationController < Madmin::BaseController
    # Routes already require an admin (authenticate :admin_user in
    # config/routes.rb); this keeps the admin closed even if that block moves.
    before_action :authenticate_admin_user!
  end
end
