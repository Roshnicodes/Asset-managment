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
      mobile_no: "9876543210",
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

  test "returned quotation proposal maker can edit and resubmit without admin role" do
    grant_menu!("quotation_proposal_form")
    approval_channel = create_quotation_maker_channel!
    quotation_proposal, vendor_registration = create_returned_quotation_proposal!(approval_channel)

    sign_in @creator_user

    get edit_quotation_proposal_url(quotation_proposal)

    assert_response :success
    assert_select "input[type='submit'][value='Update And Resubmit']"

    patch quotation_proposal_url(quotation_proposal), params: {
      quotation_proposal: {
        theme_id: @theme.id,
        subject: "Updated returned quotation proposal subject with more than twenty words for controller regression coverage and approval resubmission after the maker corrects returned details",
        proposal_end_date: Date.current + 10.days,
        remark: "Updated after return.",
        procurement_amount_bucket: "above_10k",
        vendor_registration_ids: [vendor_registration.id],
        committee_steps_attributes: quotation_proposal.committee_steps.map do |step|
          {
            id: step.id,
            level: step.level,
            employee_master_id: step.employee_master_id
          }
        end
      }
    }

    assert_redirected_to quotation_proposal_path(quotation_proposal)
    assert_equal "pending", quotation_proposal.approval_request.reload.status
    assert_nil quotation_proposal.approval_request.return_mode
  end

  test "returned vendor registration maker can open edit form without admin role" do
    grant_menu!("vendor_registration")
    vendor_registration = create_valid_vendor_registration!(email: "returned.vendor@example.com")
    approval_request = create_approval_request_for!(vendor_registration, form_name: "Vendor Registration")
    approval_request.approval_steps.first.update!(
      status: "returned",
      remark: "Please correct vendor details.",
      actioned_at: Time.current
    )
    approval_request.update!(
      current_level: nil,
      status: "returned",
      return_mode: "employee",
      returned_by_level: approval_request.approval_steps.first.level,
      returned_to_level: nil
    )

    sign_in @creator_user

    get edit_vendor_registration_url(vendor_registration)

    assert_response :success
    assert_select "input[type='submit'][value='Update And Resubmit']"
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

  def grant_menu!(identifier, designation: @creator_employee.designation)
    MenuPermission.create!(
      stakeholder_category: @stakeholder_category,
      designation: designation,
      menu_identifier: identifier,
      can_view: true
    )
  end

  def create_quotation_maker_channel!
    approval_channel = ApprovalChannel.new(
      approval_type: "Sequential",
      form_name: "Quotation Proposal",
      stakeholder_category: @stakeholder_category,
      theme: @theme
    )
    approval_channel.approval_channel_steps.build(
      current_action: "Proposal Create",
      previous_action: "NA",
      step_number: 1,
      to_responsible_user: @creator_employee
    )
    approval_channel.approval_channel_steps.build(
      current_action: "Technical Approval",
      previous_action: "Proposal Create",
      step_number: 2,
      to_responsible_user: @approver_employee
    )
    approval_channel.save!
    approval_channel
  end

  def create_returned_quotation_proposal!(approval_channel)
    unit = Unit.create!(name: "Piece")
    second_approver = create_employee(
      name: "Approval Second",
      email: "approval.second@example.com",
      employee_code: "APPROVAL-SECOND",
      designation: "Second Approver"
    )
    third_approver = create_employee(
      name: "Approval Third",
      email: "approval.third@example.com",
      employee_code: "APPROVAL-THIRD",
      designation: "Third Approver"
    )
    vendor_registration = create_valid_vendor_registration!(email: "quotation.vendor@example.com")
    quotation_proposal = QuotationProposal.new(
      procurement_amount_bucket: "above_10k",
      proposal_end_date: Date.current + 7.days,
      remark: "Approval access quotation remark",
      subject: "Returned quotation proposal with enough descriptive words to satisfy the minimum subject validation for this regression test and confirm maker correction access after approval return",
      theme: @theme,
      user: @creator_user,
      workflow_status: "returned"
    )
    quotation_proposal.vendor_registrations << vendor_registration
    quotation_proposal.quotation_proposal_items.build(
      item_name: "Office laptop",
      quantity: 2,
      remark: "Required for returned quotation testing.",
      unit: unit
    )
    [
      @approver_employee,
      second_approver,
      third_approver
    ].each.with_index(1) do |employee, level|
      quotation_proposal.committee_steps.build(
        employee_master: employee,
        level: level,
        status: level == 2 ? "returned" : "waiting",
        remark: level == 2 ? "Please correct proposal details." : nil,
        actioned_at: level == 2 ? Time.current : nil
      )
    end
    quotation_proposal.save!

    approval_request = ApprovalRequest.create!(
      approval_channel: approval_channel,
      approvable: quotation_proposal,
      current_level: nil,
      form_name: "Quotation Proposal",
      return_mode: "employee",
      returned_by_level: 2,
      status: "returned"
    )
    approval_request.approval_steps.create!(
      current_action: "Proposal Create",
      employee_master: @creator_employee,
      level: 1,
      previous_action: "NA",
      status: "approved",
      actioned_at: Time.current
    )
    approval_request.approval_steps.create!(
      current_action: "Technical Approval",
      employee_master: @approver_employee,
      level: 2,
      previous_action: "Proposal Create",
      remark: "Please correct proposal details.",
      status: "returned",
      actioned_at: Time.current
    )

    [quotation_proposal, vendor_registration]
  end

  def create_valid_vendor_registration!(email:)
    vendor_registration = VendorRegistration.new(
      address: "Returned access address",
      block: @block,
      business_description: "Returned access business description with enough words to avoid validation issues when the record is reused in workflow tests.",
      company_status: "Active",
      contact_person_designation: "Manager",
      contact_person_name: "Contact Person",
      district: @district,
      email: email,
      firm_name: "Returned Vendor Firm",
      firm_profile: "Returned access firm profile with enough words to avoid validation issues when the record is reused in workflow tests.",
      firm_type: "Company",
      gst_no: "27ABCDE1234F1Z5",
      mobile_no: "9876543210",
      pan_no: "ABCDE1234F",
      pin_no: "123456",
      stakeholder_category: @stakeholder_category,
      state: @state,
      submitted_at: Time.current,
      submitted_ip: "127.0.0.1",
      user: @creator_user,
      vendor_name: "Returned Vendor"
    )
    vendor_registration.save!(validate: false)
    vendor_registration.themes << @theme
    vendor_registration
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
