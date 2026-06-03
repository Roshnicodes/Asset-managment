require "test_helper"

class VendorRegistrationInvitationsControllerTest < ActionDispatch::IntegrationTest
  test "vendor registration sms query token link routes to public invitation start" do
    assert_recognizes(
      {
        controller: "vendor_registration_invitations",
        action: "public_start"
      },
      "/vr?t=inviteToken1"
    )
  end

  test "vendor registration sms dynamic cta token link routes to public invitation start" do
    assert_recognizes(
      {
        controller: "vendor_registration_invitations",
        action: "public_start"
      },
      "/vr?inviteToken1"
    )
  end

  test "vendor registration sms path token link routes to public invitation page" do
    assert_recognizes(
      {
        controller: "vendor_registration_invitations",
        action: "public_show",
        token: "inviteToken1"
      },
      "/vr/inviteToken1"
    )
  end
end
