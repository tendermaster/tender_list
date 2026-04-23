require "test_helper"

class Api::V1::SearchControllerTest < ActionDispatch::IntegrationTest
  test "returns search results with public fields" do
    tender = Tender.new(
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

    TenderSearch.stub(:weighted_search, [pagy, [tender]]) do
      get "/api/v1/search", params: { q: "road construction" }
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

  test "rejects blank query" do
    get "/api/v1/search", params: { q: "   " }

    assert_response :bad_request
    assert_equal "q is required", JSON.parse(response.body)["error"]
  end

  test "caps requested pagination inputs" do
    pagy = Pagy.new(count: 0, page: 100, items: 20)
    captured_args = nil

    TenderSearch.stub(:weighted_search, lambda { |query, page, per_page:|
      captured_args = [query, page, per_page]
      [pagy, []]
    }) do
      get "/api/v1/search", params: { q: "bridge", page: 999, per_page: 999 }
    end

    assert_response :success
    assert_equal ["bridge", 100, 20], captured_args
  end

  test "rate limits repeated requests from the same ip" do
    Rails.cache.clear
    pagy = Pagy.new(count: 0, page: 1, items: 10)

    TenderSearch.stub(:weighted_search, [pagy, []]) do
      60.times do
        get "/api/v1/search", params: { q: "roads" }
        assert_response :success
      end

      get "/api/v1/search", params: { q: "roads" }
    end

    assert_response :too_many_requests
    assert_equal "rate limit exceeded", JSON.parse(response.body)["error"]
  ensure
    Rails.cache.clear
  end
end
