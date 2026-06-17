require "test_helper"

class ApplicationCacheHeadersTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "authenticated pages are not browser cached" do
    sign_in users(:one)

    get employee_masters_url

    assert_response :success
    assert_equal "no-store, no-cache, must-revalidate, max-age=0", response.headers["Cache-Control"]
    assert_equal "no-cache", response.headers["Pragma"]
    assert_equal "0", response.headers["Expires"]
  end
end
