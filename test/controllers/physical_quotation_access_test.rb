require "test_helper"

# The maker can key in a quotation the vendor handed over on paper, but only
# after the committee has cleared the request - without that gate the
# physical_entry flag would be a way around the vendor's OTP.
class PhysicalQuotationAccessTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  self.fixture_table_names = []

  setup do
    @stakeholder_category = StakeholderCategory.create!(name: "Physical Entry Stakeholder")
    @theme = Theme.create!(name: "Physical Entry Theme", stakeholder_category: @stakeholder_category)
    @state = State.create!(name: "Physical Entry State", code: "PES")
    @district = District.create!(name: "Physical Entry District", state: @state)
    @block = Block.create!(name: "Physical Entry Block", district: @district)
    @unit = Unit.create!(name: "Physical Entry Unit")

    @maker_employee = create_employee("Physical Maker", "physical.maker@example.com", "PE-MAKER")
    @member_employee = create_employee("Physical Member", "physical.member@example.com", "PE-MEMBER")
    @maker_user = User.find_by!(email: @maker_employee.email_id)

    @quotation_proposal = build_proposal!
    @proposal_vendor = @quotation_proposal.quotation_proposal_vendors.first
    @proposal_vendor.ensure_qr_token!
  end

  test "maker cannot skip the vendor OTP while the committee is still pending" do
    approval_request.update!(status: "pending")
    sign_in @maker_user

    get quotation_vendor_qr_url(@proposal_vendor.qr_token, direct_access: 1, physical_entry: 1, verified: 1, skip_auto_otp: 1)

    assert_response :success
    assert_select "input[name=otp_code]"
  end

  test "maker can record a physical quotation once the committee has approved" do
    approval_request.update!(status: "approved")
    sign_in @maker_user

    get quotation_vendor_qr_url(@proposal_vendor.qr_token, direct_access: 1, physical_entry: 1, verified: 1, skip_auto_otp: 1)

    assert_response :success
    assert_select "input[name=otp_code]", count: 0
    assert_select "h3", text: "Upload Scanned Physical Quotation"
  end

  test "a signed out visitor still has to verify the OTP" do
    approval_request.update!(status: "approved")

    get quotation_vendor_qr_url(@proposal_vendor.qr_token, direct_access: 1, physical_entry: 1, verified: 1, skip_auto_otp: 1)

    assert_response :success
    assert_select "input[name=otp_code]"
  end

  private

  def approval_request
    @quotation_proposal.approval_request
  end

  def create_employee(name, email, employee_code)
    EmployeeMaster.create!(
      designation: "Officer",
      employee_code: employee_code,
      email_id: email,
      name: name,
      stakeholder_category: @stakeholder_category,
      user_type: "User"
    )
  end

  def build_proposal!
    quotation_proposal = QuotationProposal.new(
      procurement_amount_bucket: "above_10k",
      proposal_end_date: Date.current + 7.days,
      remark: "Physical entry remark",
      sent_to_vendors_at: Time.current,
      subject: "Physical quotation entry subject",
      theme: @theme,
      user: @maker_user,
      workflow_status: "awaiting_vendor_response"
    )
    quotation_proposal.save!(validate: false)

    quotation_proposal.quotation_proposal_items.create!(
      item_name: "Physical Entry Item",
      max_rate: 100,
      quantity: 3,
      remark: "Physical entry item remark",
      unit: @unit
    )

    vendor_registration = VendorRegistration.new(
      address: "Physical entry address",
      block: @block,
      business_description: "Physical entry business description",
      company_status: "Active",
      contact_person_designation: "Manager",
      contact_person_name: "Contact Person",
      district: @district,
      email: "vendor.physical@example.com",
      firm_name: "Physical Entry Vendor Firm",
      firm_type: "Company",
      mobile_no: "9700000033",
      pan_no: "ABCDE1122F",
      pin_no: "123460",
      stakeholder_category: @stakeholder_category,
      state: @state,
      submitted_at: Time.current,
      submitted_ip: "127.0.0.1",
      user: @maker_user,
      vendor_name: "Physical Entry Vendor"
    )
    vendor_registration.save!(validate: false)
    quotation_proposal.quotation_proposal_vendors.create!(vendor_registration: vendor_registration)

    channel = ApprovalChannel.new(
      approval_type: "Sequential",
      form_name: "Quotation Proposal",
      stakeholder_category: @stakeholder_category,
      theme: @theme
    )
    channel.approval_channel_steps.build(
      current_action: "L1 Approval",
      previous_action: "NA",
      step_number: 1,
      to_responsible_user: @member_employee
    )
    channel.save!

    request = ApprovalRequest.create!(
      approval_channel: channel,
      approvable: quotation_proposal,
      current_level: 1,
      form_name: "Quotation Proposal",
      status: "pending"
    )
    request.approval_steps.create!(
      current_action: "L1 Approval",
      employee_master: @member_employee,
      level: 1,
      previous_action: "NA",
      status: "pending"
    )

    quotation_proposal
  end
end
