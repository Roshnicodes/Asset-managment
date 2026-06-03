require "test_helper"

class VendorRegistrationInvitationsControllerTest < ActionDispatch::IntegrationTest
  test "vendor registration sms token link routes to public invitation start" do
    assert_recognizes(
      {
        controller: "vendor_registration_invitations",
        action: "public_start"
      },
      "/vr?t=inviteToken1"
    )
  end
end
