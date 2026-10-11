require 'test_helper'

class UserTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test 'from_google creates a confirmed user without sending a confirmation email' do
    assert_no_emails do
      user = User.from_google(uid: 'g1', email: 'New.Person@Example.com', email_verified: true, name: 'New Person')
      assert user.persisted?
      assert user.confirmed?
      assert_equal 'new.person@example.com', user.email
      assert_equal 'g1', user.google_uid
    end
  end

  test 'from_google finds the user by Google id even if their email changed' do
    user = User.from_google(uid: 'g1', email: 'old@example.com', email_verified: true)
    assert_equal user, User.from_google(uid: 'g1', email: 'new@example.com', email_verified: true)
  end

  test 'from_google refuses an email Google has not verified' do
    assert_nil User.from_google(uid: 'g1', email: 'x@example.com', email_verified: false)
  end

  test 'from_google keeps the password of a confirmed account it links' do
    user = User.create!(email: 'real@example.com', password: 'real-pass-123', confirmed_at: Time.current)
    assert_equal user, User.from_google(uid: 'g1', email: 'real@example.com', email_verified: true)
    assert user.reload.valid_password?('real-pass-123')
    assert_equal 'g1', user.google_uid
  end

  test 'from_google drops the password of an unconfirmed account it links' do
    # Someone signed up with an address they don't own, before its owner came
    squatted = User.create!(email: 'owner@example.com', password: 'attacker-pass')
    user = User.from_google(uid: 'g1', email: 'owner@example.com', email_verified: true)
    assert_equal squatted, user
    assert user.confirmed?
    assert_not user.reload.valid_password?('attacker-pass')
  end
end
