require "test_helper"

# When the quotation link SMS goes to each vendor, the maker who created the
# quotation gets a copy of every link so they can track it.
class QuotationMakerLinkCopyTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @stakeholder_category = StakeholderCategory.create!(name: "Link Copy Stakeholder")
    @theme = Theme.create!(name: "Link Copy Theme", stakeholder_category: @stakeholder_category)
    @state = State.create!(name: "Link Copy State", code: "LCS")
    @district = District.create!(name: "Link Copy District", state: @state)
    @block = Block.create!(name: "Link Copy Block", district: @district)
    @unit = Unit.create!(name: "Link Copy Unit")
  end

  test "each vendor link also goes to the maker" do
    quotation_proposal = build_proposal(maker_mobile: "9876500033", vendor_mobiles: %w[9700000041 9700000042])

    sent_to = capture_sms_numbers { quotation_proposal.send_to_vendors! }

    assert_equal %w[9700000041 9876500033 9700000042 9876500033], sent_to
    assert_equal :sent, quotation_proposal.maker_link_copy_status
    assert quotation_proposal.reload.sent_to_vendors_at.present?
  end

  test "a maker without a mobile number does not block sending to vendors" do
    quotation_proposal = build_proposal(maker_mobile: nil, vendor_mobiles: %w[9700000041])

    sent_to = capture_sms_numbers { quotation_proposal.send_to_vendors! }

    assert_equal %w[9700000041], sent_to
    assert_equal :no_mobile, quotation_proposal.maker_link_copy_status
    assert quotation_proposal.reload.sent_to_vendors_at.present?
  end

  test "a failed maker copy is reported but the vendors still receive the link" do
    quotation_proposal = build_proposal(maker_mobile: "9876500033", vendor_mobiles: %w[9700000041])
    responses = [true, false]

    QuotationVendorSmsGateway.stub(:send_vendor_link, ->(*_args, **_kwargs) { responses.shift }) do
      quotation_proposal.send_to_vendors!
    end

    assert_equal :failed, quotation_proposal.maker_link_copy_status
    assert quotation_proposal.reload.sent_to_vendors_at.present?
  end

  private

  def capture_sms_numbers
    sent_to = []
    fake = lambda do |dispatch, mobile_no: dispatch.mobile_no|
      sent_to << mobile_no
      true
    end
    QuotationVendorSmsGateway.stub(:send_vendor_link, fake) { yield }
    sent_to
  end

  def build_proposal(maker_mobile:, vendor_mobiles:)
    maker = EmployeeMaster.create!(
      designation: "Officer",
      employee_code: "LC-MAKER-#{SecureRandom.hex(3)}",
      email_id: "link.copy.maker.#{SecureRandom.hex(3)}@example.com",
      mobile_no: maker_mobile,
      name: "Link Copy Maker",
      stakeholder_category: @stakeholder_category,
      user_type: "User"
    )
    maker_user = User.find_by!(email: maker.email_id)

    quotation_proposal = QuotationProposal.new(
      committee_approval_required: false,
      procurement_amount_bucket: "above_10k",
      proposal_end_date: Date.current + 7.days,
      remark: "Link copy remark",
      subject: "Link copy quotation subject words",
      theme: @theme,
      user: maker_user
    )
    quotation_proposal.save!(validate: false)
    quotation_proposal.quotation_proposal_items.create!(item_name: "Link Copy Item", max_rate: 100, quantity: 2, remark: "Item remark", unit: @unit)

    vendor_mobiles.each_with_index do |mobile, index|
      vendor_registration = VendorRegistration.new(
        address: "Link copy address",
        block: @block,
        business_description: "Link copy business description",
        company_status: "Active",
        contact_person_designation: "Manager",
        contact_person_name: "Contact Person",
        district: @district,
        email: "link.copy.vendor#{index}@example.com",
        firm_name: "Link Copy Firm #{index}",
        firm_type: "Company",
        mobile_no: mobile,
        pan_no: "ABCDE#{1300 + index}F",
        pin_no: "123480",
        stakeholder_category: @stakeholder_category,
        state: @state,
        submitted_at: Time.current,
        submitted_ip: "127.0.0.1",
        user: maker_user,
        vendor_name: "Link Copy Vendor #{index}"
      )
      vendor_registration.save!(validate: false)
      quotation_proposal.quotation_proposal_vendors.create!(vendor_registration: vendor_registration)
    end

    quotation_proposal.reload
  end
end
