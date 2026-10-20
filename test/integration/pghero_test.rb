require 'test_helper'

class PgheroTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test 'the database dashboard is for signed-in admins only' do
    get '/admin/pghero'
    assert_response :redirect
    assert_match %r{/admin/login}, response.location

    # The page itself needs pg_stat_statements, which the test database
    # doesn't load; production does
    sign_in AdminUser.create!(email: 'admin@example.com', password: 'secret-password-1')
    get '/admin'
    assert_select "a[href='/admin/pghero']", /PgHero/
  end
end
