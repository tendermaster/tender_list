require 'test_helper'

class GoogleSignInTest < ActionDispatch::IntegrationTest
  include GoogleTokenHelper

  def sign_in_with_google(token = google_token, csrf: 'csrf-value', return_to: nil)
    cookies[:g_csrf_token] = 'csrf-value'
    post user_google_sign_in_path, params: { credential: token, g_csrf_token: csrf, return_to: return_to }.compact
  end

  test 'signs in, remembers the user and stays on the page' do
    sign_in_with_google(return_to: '/tender/abc')

    assert_response :success
    assert_equal({ 'redirect' => '/tender/abc', 'new_user' => true }, response.parsed_body)
    assert cookies[:remember_user_token].present?
    get queries_path
    assert_response :success
  end

  test 'a returning user is not reported as new' do
    User.from_google(uid: 'google-123', email: 'person@example.com', email_verified: true)
    sign_in_with_google
    assert_equal false, response.parsed_body['new_user']
  end

  test 'goes to the dashboard when there is no page to return to, never to another site' do
    sign_in_with_google(return_to: '//evil.example/x')
    assert_equal queries_path, response.parsed_body['redirect']
  end

  test 'rejects a request without the matching double-submit token' do
    sign_in_with_google(csrf: 'something-else')
    assert_response :forbidden
    assert_nil User.find_by(google_uid: 'google-123')
  end

  test 'rejects an invalid token' do
    sign_in_with_google(google_token(aud: 'someone-else'))
    assert_response :unauthorized
  end

  test 'rejects an unverified email and a locked account' do
    sign_in_with_google(google_token(email_verified: false))
    assert_response :forbidden

    User.from_google(uid: 'google-123', email: 'person@example.com', email_verified: true).lock_access!(send_instructions: false)
    sign_in_with_google
    assert_response :forbidden
  end

  test 'One Tap runs on logged-out pages only' do
    get new_user_session_path
    assert_includes response.body, 'data-controller="google-sign-in"'

    sign_in_with_google
    get queries_path
    assert_not_includes response.body, 'data-controller="google-sign-in"'
  end

  test 'signing out tells the page not to sign straight back in' do
    sign_in_with_google
    delete destroy_user_session_path
    assert_equal '1', cookies[:signed_out]
  end

  test 'opening the sign-in page from a tender returns there after an email login' do
    User.create!(email: 'email@example.com', password: 'email-pass-123', confirmed_at: Time.current)
    get new_user_session_path, headers: { 'Referer' => 'http://www.example.com/tender/xyz?ref=1' }
    post user_session_path, params: { user: { email: 'email@example.com', password: 'email-pass-123' } }
    assert_redirected_to '/tender/xyz?ref=1'
  end

  test 'while mail is off, unconfirmed email users can log in' do
    allowed_was = Devise.allow_unconfirmed_access_for
    Devise.allow_unconfirmed_access_for = nil # as config/initializers/devise.rb sets it without MAIL_ENABLED
    User.create!(email: 'unconfirmed@example.com', password: 'email-pass-123')
    post user_session_path, params: { user: { email: 'unconfirmed@example.com', password: 'email-pass-123' } }
    assert_redirected_to queries_path
  ensure
    Devise.allow_unconfirmed_access_for = allowed_was
  end
end
