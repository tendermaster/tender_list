require "application_system_test_case"

class QueriesTest < ApplicationSystemTestCase
  setup do
    @query = queries(:one)
  end

  test "visiting the index" do
    visit queries_url
    assert_selector "h1", text: "Queries"
  end

  test "should create query" do
    visit queries_url
    click_on "New query"

    fill_in "Exclude keyword", with: @query.exclude_keyword
    fill_in "Include keyword", with: @query.include_keyword
    fill_in "Name", with: @query.name
    fill_in "Query type", with: @query.query_type
    fill_in "State name", with: @query.state_name
    fill_in "User", with: @query.user_id
    click_on "Create Query"

    assert_text "Query was successfully created"
    click_on "Back"
  end

  test "should update Query" do
    visit query_url(@query)
    click_on "Edit this query", match: :first

    fill_in "Exclude keyword", with: @query.exclude_keyword
    fill_in "Include keyword", with: @query.include_keyword
    fill_in "Name", with: @query.name
    fill_in "Query type", with: @query.query_type
    fill_in "State name", with: @query.state_name
    fill_in "User", with: @query.user_id
    click_on "Update Query"

    assert_text "Query was successfully updated"
    click_on "Back"
  end

  test "should destroy Query" do
    visit query_url(@query)
    click_on "Destroy this query", match: :first

    assert_text "Query was successfully destroyed"
  end
end
