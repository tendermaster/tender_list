require 'test_helper'

# A signed-out visitor who didn't pass the captcha (Captcha#captcha_failure):
# never silently dropped. Real requests from India are kept for the call
# list, marked; the rest is spam; an invalid form says plainly it wasn't sent.
class LeadCaptchaTest < ActionDispatch::IntegrationTest
  setup do
    @env = ENV.values_at('TURNSTILE_SITE_KEY', 'TURNSTILE_SECRET_KEY')
    ENV['TURNSTILE_SITE_KEY'] = 'site-key'
    ENV['TURNSTILE_SECRET_KEY'] = 'secret-key'
  end

  teardown { ENV['TURNSTILE_SITE_KEY'], ENV['TURNSTILE_SECRET_KEY'] = @env }

  def alerts(country:, **params)
    post '/get-relevant-tenders', params: { fill_ms: 20_000, name: 'Asha Rao', mobile: '98765 43210',
                                            sectors: 'Road works', bid_help: 'Yes, help me bid' }.merge(params),
                                  headers: { 'CF-IPCountry' => country }
  end

  test 'a request from India with an Indian mobile is kept for the call list, marked' do
    alerts(country: 'IN')
    assert_response :success
    assert_select '#notice', /Thank you/
    lead = Lead.sole
    assert lead.pending?
    assert_equal 'Captcha not passed (missing token): check before calling', lead.note
    assert_equal '+919876543210', lead.phone
  end

  test 'from elsewhere it is spam, and the visitor is thanked the same' do
    alerts(country: 'NL')
    assert_response :success
    assert_select '#notice', /Thank you/
    assert Lead.sole.spam?
    assert_equal 'Spam: captcha not passed (missing token)', Lead.sole.note
  end

  test 'an invalid form says it was not sent, with the way back' do
    alerts(country: 'IN', mobile: '', name: '')
    assert_response :unprocessable_content
    assert_select '#form-error', /Your request was not sent/
    assert_select '#form-error a', 'Go back and try again'
    assert_select '#notice', count: 0
    assert_equal 0, Lead.count
  end

  test 'an enquiry form from India without the captcha is kept too' do
    post enquiry_path('callback'), params: { fill_ms: 10_000, lead: { name: 'Asha', phone: '9876543210', answers: { message: 'Call me' } } },
                                   headers: { 'CF-IPCountry' => 'IN' }
    assert_redirected_to enquiry_path('callback', sent: 1)
    assert Lead.sole.pending?
    assert_match 'Captcha not passed', Lead.sole.note
  end
end
