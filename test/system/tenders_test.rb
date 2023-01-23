require "application_system_test_case"

class TendersTest < ApplicationSystemTestCase
  setup do
    @tender = tenders(:one)
  end

  test "visiting the index" do
    visit tenders_url
    assert_selector "h1", text: "Tenders"
  end

  test "should create tender" do
    visit tenders_url
    click_on "New tender"

    fill_in "Attachments", with: @tender.attachments_id
    fill_in "Description", with: @tender.description
    fill_in "Organisation", with: @tender.organisation
    fill_in "Search data", with: @tender.search_data
    fill_in "State", with: @tender.state
    fill_in "Submission close date", with: @tender.submission_close_date
    fill_in "Submission open date", with: @tender.submission_open_date
    fill_in "Tenderid", with: @tender.tenderId
    fill_in "Tender value", with: @tender.tender_value
    fill_in "Title", with: @tender.title
    click_on "Create Tender"

    assert_text "Tender was successfully created"
    click_on "Back"
  end

  test "should update Tender" do
    visit tender_url(@tender)
    click_on "Edit this tender", match: :first

    fill_in "Attachments", with: @tender.attachments_id
    fill_in "Description", with: @tender.description
    fill_in "Organisation", with: @tender.organisation
    fill_in "Search data", with: @tender.search_data
    fill_in "State", with: @tender.state
    fill_in "Submission close date", with: @tender.submission_close_date
    fill_in "Submission open date", with: @tender.submission_open_date
    fill_in "Tenderid", with: @tender.tenderId
    fill_in "Tender value", with: @tender.tender_value
    fill_in "Title", with: @tender.title
    click_on "Update Tender"

    assert_text "Tender was successfully updated"
    click_on "Back"
  end

  test "should destroy Tender" do
    visit tender_url(@tender)
    click_on "Destroy this tender", match: :first

    assert_text "Tender was successfully destroyed"
  end
end
