require 'test_helper'

class AdminDashboardTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test 'signed-out visitors are sent to the admin login' do
    get '/admin'
    assert_redirected_to '/admin/login'
  end

  test 'shows users, subscriptions, scrapers and saved searches' do
    user = User.create!(email: 'buyer@example.com', password: 'secret-password-1', name: 'Buyer', confirmed_at: Time.current)
    Subscription.create!(user_id: user.id, plan_name: 'PAID', price: 1999, start_date: 1.day.ago, end_date: 30.days.from_now)
    Query.create!(user:, name: 'Solar', include_keyword: 'solar panel', updates: 'WEEKLY')
    Tender.create!(tender_id: 'T-1', title: 'Solar plant', tender_source: 'delhi', slug_uuid: SecureRandom.uuid,
                   submission_close_date: 5.days.from_now, updated_at_auto: 1.hour.ago)

    sign_in AdminUser.create!(email: 'admin@example.com', password: 'secret-password-1')
    get '/admin'

    assert_response :success
    assert_select 'h1', 'Dashboard'
    assert_select 'td a', 'buyer@example.com'
    assert_select 'td', 'delhi'
    assert_select 'td a', 'Solar'
    assert_includes response.body, '₹1,999'
  end

  test 'list pages show the useful columns' do
    User.create!(email: 'buyer@example.com', password: 'secret-password-1', confirmed_at: Time.current)
    lead = MiscDataStore.create!(name: 'checklist_download', source: 'homepage',
                                 data: { full_name: 'Asha', email: 'asha@example.com', mobile: '9876543210' })
    sign_in AdminUser.create!(email: 'admin@example.com', password: 'secret-password-1')

    %w[users subscriptions tenders bookmarks coupons misc_data_stores queries search_queries attachments admin_users].each do |page|
      get "/admin/#{page}"
      assert_response :success, page
    end

    get '/admin/users'
    assert_select 'th', /Email/
    assert_select 'td', 'buyer@example.com'

    get '/admin/misc_data_stores'
    assert_select 'th', /Data/
    assert_select 'td span', /full_name: Asha · email: asha@example.com/

    get "/admin/misc_data_stores/#{lead.id}"
    assert_select 'pre', /"mobile": "9876543210"/
  end

  test 'admins can log in as a user without touching their sign-in stats' do
    user = User.create!(email: 'buyer@example.com', password: 'secret-password-1', confirmed_at: Time.current,
                        sign_in_count: 4)

    post "/admin/users/#{user.id}/impersonate"
    assert_redirected_to '/admin/login'

    sign_in AdminUser.create!(email: 'admin@example.com', password: 'secret-password-1')
    get "/admin/users/#{user.id}"
    assert_select 'button', 'Log in as'

    post "/admin/users/#{user.id}/impersonate"
    assert_redirected_to '/'
    assert_equal 4, user.reload.sign_in_count

    get '/admin'
    assert_response :success, 'the admin stays signed in'
    get '/admin2'
    assert_redirected_to '/admin/users'
  end
end
