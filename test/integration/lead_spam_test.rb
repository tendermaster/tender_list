require 'test_helper'

# What the public lead forms do with spam that solved the captcha
class LeadSpamTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def callback(fill_ms: 10_000, **lead)
    post enquiry_path('callback'), params: { fill_ms:, lead: { name: 'Asha', email: 'asha@example.com', phone: '9876543210',
                                                                answers: { message: 'Please call' } }.merge(lead) }.compact
  end

  test 'spam is thanked, kept with the reason, and left off the call list' do
    callback(fill_ms: 900)
    assert_redirected_to enquiry_path('callback', sent: 1)
    callback(fill_ms: nil)
    callback(answers: { message: 'Лучшие площадки' })
    callback(email: 'x.ow.al.oro.gu.fe@gmail.com')
    post enquiry_path('callback'), params: { website: 'spam.example', fill_ms: 10_000,
                                             lead: { name: 'Bot', email: 'b@example.com', phone: '9876543210', answers: { message: 'Hi' } } }

    assert_equal ['Spam: sent too fast', 'Spam: sent without the page script', 'Spam: links or foreign script',
                  'Spam: dotted Gmail address', 'Spam: hidden field filled in'], Lead.order(:id).pluck(:note)
    assert Lead.all.all?(&:spam?)

    sign_in AdminUser.create!(email: 'admin@example.com', password: 'secret-password-1')
    get '/admin'
    assert_select 'td', text: 'Request a call back', count: 0
    assert_select 'a', '5 marked spam this week'
  end

  test 'throwaway email addresses are refused' do
    callback(email: 'someone@mailinator.com')
    assert_response :unprocessable_entity
    assert_select '#alert li', /throwaway email/
  end

  test 'numbers from other countries are accepted with their country code' do
    callback(phone: '01711102539')
    assert_select '#alert li', /country code/

    callback(phone: '+880 1711-102539')
    assert_equal '+8801711102539', Lead.sole.phone
    assert Lead.sole.pending?
  end

  test 'signed-in users are not checked for spam' do
    user = User.create!(email: 'buyer@example.com', name: 'Ravi', password: 'secret-password-1',
                        confirmed_at: Time.current, phone: '9876543210')
    sign_in user
    post enquiry_path('callback'), params: { lead: { answers: { message: 'Please call' } } }
    assert Lead.sole.pending?
  end
end
