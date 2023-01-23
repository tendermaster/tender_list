require "test_helper"

class TendersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tender = tenders(:one)
  end

  test "should get index" do
    get tenders_url
    assert_response :success
  end

  test "should get new" do
    get new_tender_url
    assert_response :success
  end

  test "should create tender" do
    assert_difference("Tender.count") do
      post tenders_url, params: { tender: { attachments_id: @tender.attachments_id, description: @tender.description, organisation: @tender.organisation, search_data: @tender.search_data, state: @tender.state, submission_close_date: @tender.submission_close_date, submission_open_date: @tender.submission_open_date, tenderId: @tender.tenderId, tender_value: @tender.tender_value, title: @tender.title } }
    end

    assert_redirected_to tender_url(Tender.last)
  end

  test "should show tender" do
    get tender_url(@tender)
    assert_response :success
  end

  test "should get edit" do
    get edit_tender_url(@tender)
    assert_response :success
  end

  test "should update tender" do
    patch tender_url(@tender), params: { tender: { attachments_id: @tender.attachments_id, description: @tender.description, organisation: @tender.organisation, search_data: @tender.search_data, state: @tender.state, submission_close_date: @tender.submission_close_date, submission_open_date: @tender.submission_open_date, tenderId: @tender.tenderId, tender_value: @tender.tender_value, title: @tender.title } }
    assert_redirected_to tender_url(@tender)
  end

  test "should destroy tender" do
    assert_difference("Tender.count", -1) do
      delete tender_url(@tender)
    end

    assert_redirected_to tenders_url
  end
end
