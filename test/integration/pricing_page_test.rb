require 'test_helper'

# /pricing sells the team's work; finding tenders is free
class PricingPageTest < ActionDispatch::IntegrationTest
  test 'services first, each to its form; no subscription plans or email promises' do
    get pricing_path
    assert_response :success
    assert_select 'h1', 'Pricing & Services'
    assert_select '#services h3', %w[Bid\ filing GeM\ registration Get\ bid-ready Tender\ desk].size
    assert_select '#services a[href=?]', enquiry_path('bid_support'), 'Get a quote'
    assert_select '#services a[href=?]', enquiry_path('gem_registration')
    assert_select 'a[href=?]', get_relevant_tenders_path, 'Get tenders on WhatsApp'
    assert_not_includes response.body, 'rzp.io'
    assert_no_match(/inbox|email notifications/i, response.body)
    # The side consultations aren't sold here
    assert_select "a[href='#{enquiry_path('fcra')}']", count: 0
    assert_select "a[href^='https://company-setup.']", count: 0
  end
end
