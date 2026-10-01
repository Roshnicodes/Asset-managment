require "test_helper"

class ApprovalAssignedRecordAccessTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  self.fixture_table_names = []

  setup do
    @stakeholder_category = StakeholderCategory.create!(name: "Approval Access Stakeholder")
    @theme = Theme.create!(name: "Approval Access Theme", stakeholder_category: @stakeholder_category)
    @state = State.create!(name: "Approval Access State", code: "AAS")
    @district = District.create!(name: "Approval Access District", state: @state)
    @block = Block.create!(name: "Approval Access Block", district: @district)

    @creator_employee = create_employee(
      name: "Approval Creator",
      email: "approval.creator@example.com",
      employee_code: "APPROVAL-CREATOR",
      designation: "Maker"
    )
    @approver_employee = create_employee(
      name: "Approval Assignee",
      email: "approval.assignee@example.com",
      employee_code: "APPROVAL-ASSIGNEE",
      designation: "Approver Without Menu Rights"
    )
    @creator_user = User.find_by!(email: @creator_employee.email_id)
    @approver_user = User.find_by!(email: @approver_employee.email_id)
  end

  test "assigned approver can view vendor registration without vendor menu rights" do
    vendor_registration = VendorRegistration.new(
      address: "Approval test address",
      block: @block,
      business_description: "Approval test business description",
      company_status: "Active",
      contact_person_designation: "Manager",
      contact_person_name: "Contact Person",
      district: @district,
      email: "vendor.approval@example.com",
      firm_name: "Approval Vendor Firm",
      firm_type: "Company",
      mobile_no: "9811122233",
      pan_no: "ABCDE1234F",
      pin_no: "123456",
      stakeholder_category: @stakeholder_category,
      state: @state,
      submitted_at: Time.current,
      submitted_ip: "127.0.0.1",
      user: @creator_user,
      vendor_name: "Approval Vendor"
    )
    vendor_registration.save!(validate: false)
    create_approval_request_for!(vendor_registration, form_name: "Vendor Registration")

    sign_in @approver_user

    get vendor_registration_url(vendor_registration)

    assert_response :success
    assert_select "h2", /Vendor Registration Details/
  end

  test "assigned approver can view quotation proposal without quotation menu rights" do
    quotation_proposal = QuotationProposal.new(
      procurement_amount_bucket: "above_10k",
      proposal_end_date: Date.current + 7.days,
      remark: "Approval access quotation remark",
      subject: "Approval access quotation proposal with enough words for the show page smoke test",
      theme: @theme,
      user: @creator_user,
      workflow_status: "committee_pending"
    )
    quotation_proposal.save!(validate: false)
    create_approval_request_for!(quotation_proposal, form_name: "Quotation Proposal")

    sign_in @approver_user

    get quotation_proposal_url(quotation_proposal)

    assert_response :success
    assert_select ".quotation-proposal-show"
  end

  test "unassigned user without menu rights still cannot view approval record" do
    other_employee = create_employee(
      name: "Unassigned User",
      email: "unassigned.approval@example.com",
      employee_code: "UNASSIGNED-APPROVAL",
      designation: "No Menu Rights"
    )
    vendor_registration = VendorRegistration.new(
      address: "Unassigned access address",
      block: @block,
      business_description: "Unassigned access business description",
      company_status: "Active",
      contact_person_designation: "Manager",
      contact_person_name: "Contact Person",
      district: @district,
      email: "vendor.unassigned@example.com",
      firm_name: "Unassigned Vendor Firm",
      firm_type: "Company",
      mobile_no: "9876543211",
      pan_no: "ABCDE1235F",
      pin_no: "123457",
      stakeholder_category: @stakeholder_category,
      state: @state,
      submitted_at: Time.current,
      submitted_ip: "127.0.0.1",
      user: @creator_user,
      vendor_name: "Unassigned Vendor"
    )
    vendor_registration.save!(validate: false)
    create_approval_request_for!(vendor_registration, form_name: "Vendor Registration")

    sign_in User.find_by!(email: other_employee.email_id)

    get vendor_registration_url(vendor_registration)

    assert_redirected_to root_path
  end

  private

  def create_employee(name:, email:, employee_code:, designation:)
    EmployeeMaster.create!(
      designation: designation,
      employee_code: employee_code,
      email_id: email,
      name: name,
      stakeholder_category: @stakeholder_category,
      user_type: "User"
    )
  end

  def create_approval_request_for!(approvable, form_name:)
    approval_channel = ApprovalChannel.new(
      approval_type: "Sequential",
      form_name: form_name,
      stakeholder_category: @stakeholder_category,
      theme: @theme
    )
    approval_channel.approval_channel_steps.build(
      current_action: "Technical Approval",
      previous_action: "NA",
      step_number: 1,
      to_responsible_user: @approver_employee
    )
    approval_channel.save!

    approval_request = ApprovalRequest.create!(
      approval_channel: approval_channel,
      approvable: approvable,
      current_level: 1,
      form_name: form_name,
      status: "pending"
    )
    approval_request.approval_steps.create!(
      current_action: "Technical Approval",
      employee_master: @approver_employee,
      level: 1,
      previous_action: "NA",
      status: "pending"
    )
    approval_request
  end
end
