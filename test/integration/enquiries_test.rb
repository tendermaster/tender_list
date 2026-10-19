require 'test_helper'

class EnquiriesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ApplicationHelper

  def gst_answers(**overrides)
    { industry: EnquiryTopic.find('gst').fields.first.options.first, business_type: 'Trader', state: 'Kerala',
      turnover: '2 Cr', gst_registered: 'No', needs: 'Obtaining GST Registration', past_issues: 'No' }.merge(overrides)
  end

  test 'every topic has a working form' do
    assert_operator EnquiryTopic.all.size, :>=, 20
    EnquiryTopic.all.each_value do |topic|
      get enquiry_path(topic.key)
      assert_response :success, topic.key
      assert_select 'h1', topic.title
      assert_select 'input[type=submit][value=?]', topic.submit
      assert_select 'meta[name=robots][content*=noindex]'
    end
    get '/enquiry/nope'
    assert_response :not_found
  end

  test 'a visitor sends an enquiry; answers are saved by question' do
    post enquiry_path('gst'), params: { lead: { name: 'Asha', email: 'asha@example.com', phone: '9876543210',
                                                company: 'Rao Traders', designation: 'Owner', website: 'https://rao.example',
                                                answers: gst_answers } }
    assert_redirected_to enquiry_path('gst', sent: 1)

    lead = Lead.last
    assert lead.enquiry?
    assert_equal ['gst', 'Rao Traders', '+919876543210', 'GST compliance: free consultation'],
                 [lead.topic, lead.company, lead.phone, lead.subject]
    assert_equal 'No', lead.answers['Do you have a GST registration?']
    assert_equal 'Owner', lead.answers['Designation']
    assert_equal 'https://rao.example', lead.answers['Website']

    follow_redirect!
    assert_select 'h2', /received/
  end

  test 'required questions, the company and offered options are checked' do
    post enquiry_path('gst'), params: { lead: { name: 'Asha', email: 'asha@example.com', phone: '9876543210',
                                                designation: 'Owner', answers: gst_answers(gst_registered: 'Maybe?') } }
    assert_response :unprocessable_entity
    assert_select '#alert li', /Do you have a GST registration is required/
    assert_select '#alert li', /Company name is required/
    assert_equal 0, Lead.count
  end

  test 'checkbox answers keep only the offered options' do
    post enquiry_path('gem_registration'),
         params: { lead: { name: 'Asha', email: 'asha@example.com', phone: '9876543210', company: 'Rao Traders',
                           answers: { gem_status: 'Not registered yet', business_type: 'Proprietorship', offer: 'Chairs',
                                      state: 'Goa', documents: ['PAN', 'Passport', 'GST registration'] } } }
    assert_equal ['PAN', 'GST registration'], Lead.last.answers['Documents you have ready']
  end

  test 'signed-in users send enquiries with their account' do
    user = User.create!(email: 'buyer@example.com', name: 'Ravi', password: 'secret-password-1',
                        confirmed_at: Time.current, phone: '9876543210')
    sign_in user
    get enquiry_path('callback')
    assert_select 'input[name="lead[email]"]', count: 0

    post enquiry_path('callback'), params: { lead: { answers: { message: 'Please call after 5' } } }
    lead = Lead.last
    assert_equal [user, 'Ravi', 'buyer@example.com', 'Please call after 5'],
                 [lead.user, lead.name, lead.email, lead.answers['Message']]
  end

  test 'the old form pages redirect to the new forms, and no Google Forms are linked' do
    { '/get-callback' => 'callback', '/free-trial' => 'free_trial', '/partner-with-us' => 'partnership',
      '/get-sample-tenders' => 'sample_tender', '/get-relevant-tenders' => 'tender_alerts' }.each do |old, topic|
      get old
      assert_redirected_to "/enquiry/#{topic}"
      assert_equal 301, response.status
    end

    get products_path
    # Only GetSaarthi's own forms (application_helper) are still Google Forms
    getsaarthi = [getsaarthi_professional_form_url, getsaarthi_opportunity_matching_url].map { _1[%r{forms/d/e/[\w-]+}] }
    linked = response.body.scan(%r{docs\.google\.com/(forms/d/(?:e/)?[\w-]+)}).flatten.uniq
    assert_empty linked - getsaarthi
    assert_select "a[href='/enquiry/supplier']"
    assert_select "a[href='/enquiry/professional']"
  end

  test 'staff see enquiries with their answers' do
    post enquiry_path('callback'), params: { lead: { name: 'Asha', email: 'asha@example.com', phone: '9876543210',
                                                     answers: { message: 'Call me' } } }
    sign_in AdminUser.create!(email: 'admin@example.com', password: 'secret-password-1')
    get '/admin'
    assert_select 'td', 'Enquiry'
    assert_select 'td a', 'Request a call back'
    get "/admin/leads/#{Lead.last.id}"
    assert_response :success
    assert_includes response.body, 'Call me'
  end
end
