require 'test_helper'

class OnboardingTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: 'buyer@example.com', password: 'secret-password-1', name: 'Asha Rao',
                         confirmed_at: Time.current)
  end

  def submit(return_to: nil, **fields)
    patch '/welcome', params: { return_to:, onboarding: { keywords: 'solar, street lights', states: %w[Maharashtra Goa],
                                                         phone: '98765 43210', business_type: 'Contractor',
                                                         consent: '1' }.merge(fields) }.compact
  end

  test 'a first sign-in goes to /welcome, a later one does not' do
    post user_session_path, params: { user: { email: 'buyer@example.com', password: 'secret-password-1' } }
    assert_redirected_to '/welcome'

    delete destroy_user_session_path
    post user_session_path, params: { user: { email: 'buyer@example.com', password: 'secret-password-1' } }
    assert_redirected_to '/queries'
  end

  test 'saves the mobile number, business and what they bid on, then shows matches' do
    sign_in @user
    get '/welcome'
    assert_response :success
    assert_select 'h1', /Welcome, Asha/
    assert_select 'input[name="onboarding[phone]"][required]'

    submit
    query = @user.query.sole
    assert_redirected_to "/queries/tender_result/#{query.id}?onboarded=1"
    @user.reload
    assert_equal '+919876543210', @user.phone
    assert_equal 'Contractor', @user.business_type
    assert @user.onboarded_at && @user.contact_consent_at
    assert_equal ['solar, street lights', 'Maharashtra, Goa'], [query.include_keyword, query.state_name]

    # Submitting again updates the same saved search
    submit(keywords: 'CCTV')
    assert_equal 'CCTV', @user.query.sole.include_keyword
  end

  test 'someone who signed up from a tender goes back to it afterwards' do
    get new_user_session_path, headers: { 'Referer' => 'http://www.example.com/tender/xyz' }
    post user_session_path, params: { user: { email: 'buyer@example.com', password: 'secret-password-1' } }
    assert_redirected_to '/welcome?return_to=%2Ftender%2Fxyz'

    get '/welcome', params: { return_to: '/tender/xyz' }
    assert_select 'input[name=return_to][value="/tender/xyz"]'
    assert_select 'a[href="/tender/xyz"]', 'Skip for now'
    submit(return_to: '/tender/xyz')
    assert_redirected_to '/tender/xyz'

    submit(return_to: '//evil.example/x')
    assert_redirected_to "/queries/tender_result/#{@user.query.sole.id}?onboarded=1"
  end

  test 'rejects numbers that are not Indian mobiles, missing keywords and missing consent' do
    sign_in @user
    ['12345', '022 2345 6789', '+1 415 555 0100'].each do |phone|
      submit(phone:)
      assert_response :unprocessable_entity
      assert_select '#alert', /valid Indian mobile/
    end
    submit(keywords: ' , ')
    assert_select '#alert', /at least one/
    submit(consent: '0')
    assert_select '#alert', /agree/
    assert_nil @user.reload.phone
    assert_empty @user.query
  end

  test 'the finish-setup bar shows until there is a number' do
    sign_in @user
    get '/queries'
    assert_select 'a[href="/welcome"]', /Finish setup/

    @user.update!(phone: '9876543210')
    get '/queries'
    assert_select 'a[href="/welcome"]', count: 0
  end

  test 'the admin dashboard lists new sign-ups to call' do
    @user.update!(phone: '9876543210', business_type: 'Trader / Supplier')
    Query.create!(user: @user, name: 'My tenders', include_keyword: 'solar', state_name: 'Goa')
    User.create!(email: 'called@example.com', password: 'secret-password-1', confirmed_at: Time.current,
                 call_status: 'called')

    sign_in AdminUser.create!(email: 'admin@example.com', password: 'secret-password-1')
    get '/admin'
    assert_select 'a[href="tel:+919876543210"]'
    assert_select 'td', 'Goa'
    assert_no_match 'called@example.com', css_select('table').first.to_s
  end

end
