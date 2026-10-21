require "test_helper"

class Api::V1::SearchControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  setup do
    @key = ApiKey.create!(name: "Partner")
  end

  def auth = { "X-Api-Key" => @key.token }

  test "returns search results with public fields" do
    tender = Tender.create!(
      tender_source: "pwd", is_visible: true,
      slug_uuid: "road-123",
      title: "Road construction work",
      description: "District road widening package",
      organisation: "PWD",
      state: "Maharashtra",
      submission_open_date: Time.zone.parse("2026-04-01 10:00:00"),
      submission_close_date: Time.zone.parse("2026-05-01 17:00:00"),
      tender_value: 2_500_000,
      emd: 50_000,
      tender_id: "PWD-2026-17"
    )
    pagy = Pagy.new(count: 1, page: 1, items: 10)

    card = Tender.select(TenderSearch::CARD_COLUMNS).find(tender.id)   # what search returns
    stub(TenderSearch, :weighted_search, [pagy, [card]]) do
      get "/api/v1/search", params: { q: "road construction" }, headers: auth
    end

    assert_response :success

    body = JSON.parse(response.body)
    assert_equal "road construction", body["query"]
    assert_equal 1, body["page"]
    assert_equal 10, body["per_page"]
    assert_equal 1, body["total_count"]
    assert_equal 1, body["total_pages"]
    assert_equal 1, body["results"].length

    result = body["results"].first
    assert_equal "road-123", result["slug_uuid"]
    assert_equal "Road construction work", result["title"]
    assert_equal "District road widening package", result["description"]
    assert_equal "PWD", result["organisation"]
    assert_equal "Maharashtra", result["state"]
    assert_equal "2026-04-01T10:00:00Z", result["submission_open_date"]
    assert_equal "2026-05-01T17:00:00Z", result["submission_close_date"]
    assert_equal 2_500_000, result["tender_value"]
    assert_equal 50_000, result["emd"]
    assert_equal "PWD-2026-17", result["tender_id"]
    assert_equal "http://www.example.com/tender/road-123", result["page_url"]
    assert_nil result["full_data"]
  end

  test "allows cross-origin search requests from any site" do
    pagy = Pagy.new(count: 0, page: 1, items: 10)

    stub(TenderSearch, :weighted_search, [pagy, []]) do
      get "/api/v1/search", params: { q: "roads" }, headers: auth.merge("Origin" => "https://example-client.test")
    end

    assert_response :success
    assert_equal "*", response.headers["Access-Control-Allow-Origin"]
    assert_includes response.headers["Access-Control-Allow-Methods"], "GET"
  end

  test "handles cors preflight for search" do
    options "/api/v1/search", headers: {
      "Origin" => "https://example-client.test",
      "Access-Control-Request-Method" => "GET"
    }

    assert_response :no_content
    assert_equal "*", response.headers["Access-Control-Allow-Origin"]
    assert_includes response.headers["Access-Control-Allow-Methods"], "OPTIONS"
    assert_includes response.headers["Access-Control-Allow-Headers"], "Authorization"
  end

  test "rejects blank query" do
    get "/api/v1/search", params: { q: "   " }, headers: auth

    assert_response :bad_request
    assert_equal "q is required", JSON.parse(response.body)["error"]
  end

  test "caps requested pagination inputs" do
    pagy = Pagy.new(count: 2_000, page: 100, items: 20)
    captured_args = nil

    stub(TenderSearch, :weighted_search, lambda { |query, page, per_page:|
      captured_args = [query, page, per_page]
      [pagy, []]
    }) do
      get "/api/v1/search", params: { q: "bridge", page: 999, per_page: 999 }, headers: auth
    end

    assert_response :success
    assert_equal ["bridge", 100, 20], captured_args
  end

  test "rate limits repeated requests from the same ip" do
    # The throttle counts in Rails.cache, a null store in tests
    cache_was = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    pagy = Pagy.new(count: 0, page: 1, items: 10)

    stub(TenderSearch, :weighted_search, [pagy, []]) do
      60.times do
        get "/api/v1/search", params: { q: "roads" }, headers: auth
        assert_response :success
      end

      get "/api/v1/search", params: { q: "roads" }, headers: auth
    end

    assert_response :too_many_requests
    assert_equal "rate limit exceeded", JSON.parse(response.body)["error"]
  ensure
    Rails.cache = cache_was
  end

  test 'the debug and file-download endpoints are gone' do
    get '/api/v1/debug/ip'
    assert_response :not_found
    post '/api/download_file', params: { file_path: 'x.pdf', token: 'x' }
    assert_response :not_found
  end

  test "a key is required, revoked keys stop working, and a Bearer token works too" do
    get "/api/v1/search", params: { q: "roads" }
    assert_response :unauthorized
    assert_match "API key required", response.parsed_body["error"]
    assert_equal "*", response.headers["Access-Control-Allow-Origin"]

    get "/api/v1/search", params: { q: "roads" }, headers: { "X-Api-Key" => "st_wrong" }
    assert_response :unauthorized

    pagy = Pagy.new(count: 0, page: 1, items: 10)
    stub(TenderSearch, :weighted_search, [pagy, []]) do
      get "/api/v1/search", params: { q: "roads" }, headers: { "Authorization" => "Bearer #{@key.token}" }
    end
    assert_response :success
    assert_equal 1, @key.reload.requests_count
    assert @key.last_used_at

    @key.update!(active: false)
    get "/api/v1/search", params: { q: "roads" }, headers: auth
    assert_response :unauthorized
  end

  test "keys are matched on their digest and stay viewable for admins" do
    assert_match(/\Ast_\w{32}\z/, @key.token)
    assert_equal @key.token.first(9), @key.token_prefix
    assert_equal ApiKey.digest(@key.token), @key.token_digest
    assert_equal @key.token, ApiKey.find(@key.id).token

    sign_in AdminUser.create!(email: "admin@example.com", password: "secret-password-1")
    get "/admin/api_keys/#{@key.id}"
    assert_includes response.body, @key.token
    assert_select "h2", "How to use this key"
    assert_select "pre code", /curl -H "X-Api-Key: #{@key.token}"/
    assert_select "strong", "Python"
    post "/admin/api_keys", params: { api_key: { name: "GetSaarthi" } }
    assert_match(/\Ast_/, ApiKey.find_by(name: "GetSaarthi").token)
  end
end
