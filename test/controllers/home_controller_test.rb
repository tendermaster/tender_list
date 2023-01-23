require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "should get about" do
    get home_about_url
    assert_response :success
  end

  test "should get login" do
    get home_login_url
    assert_response :success
  end

  test "should get signup" do
    get home_signup_url
    assert_response :success
  end

  test "should get services" do
    get home_services_url
    assert_response :success
  end
end
