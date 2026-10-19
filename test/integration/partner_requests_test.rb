require 'test_helper'

class PartnerRequestsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @tender = Tender.create!(tender_id: 'T-1', title: 'Construction of district hospital', organisation: 'PWD Assam',
                             state: 'Assam', tender_source: 'assam', slug_uuid: SecureRandom.uuid,
                             submission_close_date: 10.days.from_now, updated_at_auto: Time.current, is_visible: true)
  end

  def request_partner(tender: @tender, **lead)
    post find_partner_path(tender: tender&.slug_uuid),
         params: { lead: { partner_need: Lead::PARTNER_NEEDS.first, details: 'Need ₹50 Cr turnover',
                           company: 'Rao Builders', annual_turnover: '₹5–50 Cr', location: 'Guwahati, Assam' }.merge(lead) }
  end

  test 'a visitor asks for a partner for a tender' do
    get find_partner_path(tender: @tender.slug_uuid)
    assert_response :success
    assert_select 'a', /Construction of district hospital/
    assert_select 'meta[name=robots][content*=noindex]'
    assert_includes response.headers['Cache-Control'], 'no-store'

    request_partner(name: 'Asha', email: 'asha@example.com', phone: '9876543210')
    assert_redirected_to find_partner_path(tender: @tender.slug_uuid, sent: 1)

    lead = Lead.last
    assert lead.partner?
    assert_equal [@tender, nil, 'Rao Builders', '₹5–50 Cr', '+919876543210', 'Construction of district hospital'],
                 [lead.tender, lead.product, lead.company, lead.annual_turnover, lead.phone, lead.subject]

    follow_redirect!
    assert_select 'h2', 'Request received'
  end

  test 'it works without a tender, and asks what kind of partner' do
    request_partner(tender: nil, partner_need: '', name: 'Asha', email: 'asha@example.com', phone: '9876543210')
    assert_response :unprocessable_entity
    assert_select '#alert li', /Partner need is not included/
    assert_equal 0, Lead.count

    request_partner(tender: nil, name: 'Asha', email: 'asha@example.com', phone: '9876543210')
    assert_equal 'Bidding partner', Lead.last.subject
  end

  test 'signed-in users ask with their account; the turnover they give is kept on it' do
    user = User.create!(email: 'buyer@example.com', name: 'Ravi', password: 'secret-password-1',
                        confirmed_at: Time.current, phone: '9876543210')
    sign_in user

    get find_partner_path(tender: @tender.slug_uuid)
    assert_select 'input[name="lead[email]"]', count: 0
    assert_select 'input[name="lead[phone]"]', count: 0

    request_partner
    lead = Lead.last
    assert_equal [user, 'buyer@example.com', '+919876543210'], [lead.user, lead.email, lead.phone]
    assert_equal '₹5–50 Cr', user.reload.annual_turnover
  end

  test 'open tenders and saved tenders link to it; closed tenders do not' do
    get tender_show_path(slug_uuid: @tender.slug_uuid)
    assert_select "a[href=?]", find_partner_path(tender: @tender.slug_uuid)

    @tender.update!(submission_close_date: 2.days.ago)
    get tender_show_path(slug_uuid: @tender.slug_uuid)
    assert_select "a[href=?]", find_partner_path(tender: @tender.slug_uuid), count: 0

    @tender.update!(submission_close_date: 10.days.from_now)
    user = User.create!(email: 'buyer@example.com', password: 'secret-password-1', confirmed_at: Time.current,
                        phone: '9876543210')
    user.bookmarks.create!(tender: @tender)
    sign_in user
    get bookmarks_path
    assert_select "a[href=?]", find_partner_path(tender: @tender.slug_uuid), 'Find a partner'
  end

  test 'staff see partner requests with quotes on the dashboard' do
    request_partner(name: 'Asha', email: 'asha@example.com', phone: '9876543210')
    sign_in AdminUser.create!(email: 'admin@example.com', password: 'secret-password-1')
    get '/admin'
    assert_select 'td', 'Partner'
    assert_select 'td a', 'Construction of district hospital'
    get "/admin/leads/#{Lead.last.id}"
    assert_response :success
    get "/admin/leads/#{Lead.last.id}/edit"
    assert_response :success
  end
end
