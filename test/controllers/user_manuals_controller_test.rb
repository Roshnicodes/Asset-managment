require "test_helper"

class UserManualsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "redirects guests to login" do
    get user_manual_url

    assert_redirected_to new_user_session_path
  end

  test "authenticated user can view manual without rbac permissions" do
    sign_in users(:one)

    get user_manual_url

    assert_response :success
    assert_includes response.body, "Asset Management User Manual"
    assert_includes response.body, "Vendor Registration"
    assert_includes response.body, "User Manual"
    assert_includes response.body, "Download PDF"
    assert_includes response.body, "/manual/download"
  end

  test "authenticated user can switch manual to hindi" do
    sign_in users(:one)

    get user_manual_url(lang: "hi")

    assert_response :success
    assert_includes response.body, "एसेट मैनेजमेंट यूजर मैनुअल"
    assert_includes response.body, "Manual खोलना और Language बदलना"
  end

  test "authenticated user can download manual pdf in english and hindi" do
    sign_in users(:one)

    get download_user_manual_url(lang: "en")
    assert_response :success
    assert_includes response.content_type, "application/pdf"
    assert_includes response.headers["Content-Disposition"], "asset-management-user-manual-en.pdf"
    assert response.body.bytesize > 100_000

    get download_user_manual_url(lang: "hi")
    assert_response :success
    assert_includes response.content_type, "application/pdf"
    assert_includes response.headers["Content-Disposition"], "asset-management-user-manual-hi.pdf"
    assert response.body.bytesize > 100_000
  end
end
