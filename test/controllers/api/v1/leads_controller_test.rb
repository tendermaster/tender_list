require 'test_helper'

# Quote requests from products.sigmatenders.com: a leads-scoped key, the
# visitor's IP and country passed on, the same spam and captcha rules as the
# site's own forms
class Api::V1::LeadsControllerTest < ActionDispatch::IntegrationTest
  include MarketplaceHelper

  setup do
    @key = ApiKey.create!(name: 'products-web', scopes: %w[marketplace leads])
    @product = marketplace_product
    @supplier = licensed_supplier('Alpha Polymers')
    @env = ENV.values_at('TURNSTILE_SITE_KEY', 'TURNSTILE_SECRET_KEY')
    ENV['TURNSTILE_SITE_KEY'] = 'site-key'
    ENV['TURNSTILE_SECRET_KEY'] = 'secret-key'
  end

  teardown { ENV['TURNSTILE_SITE_KEY'], ENV['TURNSTILE_SECRET_KEY'] = @env }

  def send_lead(key: @key.token, country: 'IN', ip: '203.0.113.7', lead: {}, **params)
    post '/api/v1/leads', as: :json, headers: { 'X-Api-Key' => key }, params: {
      category: 'hdpe-pipes', supplier: @supplier.slug, fill_ms: 20_000,
      lead: { name: 'Asha Rao', phone: '98765 43210', quantity: '500 m', location: 'Kolkata' }.merge(lead),
      visitor: { ip:, country:, page: 'https://products.sigmatenders.com/hdpe-pipes',
                 headers: { 'user-agent' => 'Test browser', 'cookie' => 'secret=1' } }
    }.merge(params)
  end

  test 'a request from India is kept for the call list, with the visitor details' do
    send_lead
    assert_response :created
    lead = Lead.sole
    assert lead.pending?
    assert_equal [@product, @supplier], [lead.product, lead.supplier]
    assert_equal 'Captcha not passed (missing token): check before calling', lead.note
    assert_equal %w[203.0.113.7 IN products.sigmatenders.com], lead.request_meta.values_at('ip', 'country', 'site')
    assert_equal({ 'user-agent' => 'Test browser' }, lead.request_meta['headers'], 'cookies are never kept')
  end

  test 'from elsewhere without a captcha it is spam, answered the same way' do
    send_lead(country: 'NL')
    assert_response :accepted
    assert_equal({ 'status' => 'received' }, response.parsed_body)
    assert Lead.sole.spam?
  end

  test 'an invalid request lists the errors' do
    send_lead(lead: { phone: '' })
    assert_response :unprocessable_content
    assert response.parsed_body['errors']['phone'].any?
    assert_equal 0, Lead.count
  end

  test 'needs a leads-scoped key and the visitor IP' do
    send_lead(key: ApiKey.create!(name: 'Partner').token)
    assert_response :forbidden

    send_lead(key: 'st_wrong')
    assert_response :unauthorized

    send_lead(ip: 'not-an-ip')
    assert_response :unprocessable_content
    assert_equal 0, Lead.count
  end

  test 'a search key still searches; a leads key cannot' do
    get '/api/v1/search', params: { q: 'pipe' }, headers: { 'X-Api-Key' => @key.token }
    assert_response :forbidden
  end
end
