require "test_helper"

# The registration link goes to the vendor and a copy goes to the maker who
# sent it, so the maker can follow the same link.
class VendorRegistrationInvitationMakerCopyTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @stakeholder_category = StakeholderCategory.create!(name: "Invite Copy Stakeholder")
  end

  test "the link goes to the vendor and a copy to the maker" do
    invitation = build_invitation(maker_mobile: "9876500011")

    sent_to = capture_sms_numbers { assert_equal :sent, invitation.send_registration_link! }

    assert_equal ["9811100022", "9876500011"], sent_to
    assert_equal "sent", invitation.reload.status
  end

  test "a maker without a mobile number does not block the vendor invite" do
    invitation = build_invitation(maker_mobile: nil)

    sent_to = capture_sms_numbers { assert_equal :no_mobile, invitation.send_registration_link! }

    assert_equal ["9811100022"], sent_to
    assert_equal "sent", invitation.reload.status
  end

  test "a failed maker copy is reported but the vendor invite still counts" do
    invitation = build_invitation(maker_mobile: "9876500011")
    responses = [true, false]

    QuotationVendorSmsGateway.stub(:send_vendor_registration_link, ->(*_args, **_kwargs) { responses.shift }) do
      assert_equal :failed, invitation.send_registration_link!
    end
    assert_equal "sent", invitation.reload.status
  end

  private

  def capture_sms_numbers
    sent_to = []
    fake = lambda do |invitation, mobile_no: invitation.mobile_no|
      sent_to << mobile_no
      true
    end
    QuotationVendorSmsGateway.stub(:send_vendor_registration_link, fake) { yield }
    sent_to
  end

  def build_invitation(maker_mobile:)
    maker = EmployeeMaster.create!(
      designation: "Officer",
      employee_code: "INV-MAKER-#{SecureRandom.hex(3)}",
      email_id: "invite.maker.#{SecureRandom.hex(3)}@example.com",
      mobile_no: maker_mobile,
      name: "Invite Maker",
      stakeholder_category: @stakeholder_category,
      user_type: "User"
    )

    VendorRegistrationInvitation.create!(
      mobile_no: "9811100022",
      stakeholder_category: @stakeholder_category,
      user: User.find_by!(email: maker.email_id)
    )
  end
end
