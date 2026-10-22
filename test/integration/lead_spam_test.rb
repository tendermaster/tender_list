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

  test 'spam with junk a real lead would be refused for is still kept' do
    post '/get-relevant-tenders', params: { website: 'http://spam.example', fill_ms: 10_000, name: 'x' * 300,
                                            email: 'not-an-email', mobile: '123', sectors: 'seo services' }
    assert_response :success
    assert_equal 'Spam: hidden field filled in', Lead.sole.note
    assert Lead.sole.spam?
  end

  test 'a saved lead tells GA once; spam never does' do
    callback
    follow_redirect!
    assert_select 'script', /gtag\('event', 'generate_lead', \{ lead_type: "callback" \}\)/
    get enquiry_path('callback')
    assert_select 'script', text: /generate_lead/, count: 0

    callback(fill_ms: 900)
    follow_redirect!
    assert_select 'script', text: /generate_lead/, count: 0
  end

  test 'each lead keeps its IP, country, page and headers, never the secret ones' do
    post enquiry_path('callback'),
         params: { fill_ms: 10_000, lead: { name: 'Asha', email: 'asha@example.com', phone: '9876543210',
                                            answers: { message: 'Please call' } } },
         headers: { 'CF-IPCountry' => 'IN', 'User-Agent' => 'Mozilla/5.0 (Android)', 'Referer' => 'https://sigmatenders.com/tender/abc',
                    'Cookie' => 'secret_session=1', 'Authorization' => 'Bearer st_x', 'X-Api-Key' => 'st_y' }
    meta = Lead.sole.request_meta
    assert_equal '127.0.0.1', meta['ip']
    assert_equal 'IN', meta['country']
    assert_equal 'IN', Lead.sole.country
    assert_equal 'https://sigmatenders.com/tender/abc', meta['page']
    assert_equal 'Mozilla/5.0 (Android)', meta.dig('headers', 'user-agent')
    assert_empty meta['headers'].keys & %w[cookie authorization x-api-key]
    assert_not_includes meta.to_json, 'secret_session'

    sign_in AdminUser.create!(email: 'admin@example.com', password: 'secret-password-1')
    get "/admin/leads/#{Lead.sole.id}"
    assert_includes response.body, 'Mozilla/5.0 (Android)'
    get '/admin/leads', params: { sort: 'country' }
    assert_response :success
  end

  test 'spam loses its request details after 90 days; real leads keep them' do
    callback(fill_ms: 900)
    callback
    Lead.update_all(created_at: 91.days.ago)
    LeadMetaCleanupJob.new.perform
    assert_equal({}, Lead.spam.sole.request_meta)
    assert Lead.pending.sole.request_meta['ip']
  end

  test 'admin lists spam only under the Spam tab' do
    callback(name: 'Real Person')
    callback(name: 'Bot Person', fill_ms: 900)
    sign_in AdminUser.create!(email: 'admin@example.com', password: 'secret-password-1')

    %w[all enquiry pending].each do |scope|
      get '/admin/leads', params: { scope: }
      assert_includes response.body, 'Real Person'
      assert_not_includes response.body, 'Bot Person', "spam listed under #{scope}"
    end
    get '/admin/leads', params: { scope: 'spam' }
    assert_includes response.body, 'Bot Person'
    assert_not_includes response.body, 'Real Person'
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
