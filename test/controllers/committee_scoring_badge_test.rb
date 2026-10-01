require "test_helper"

class CommitteeScoringBadgeTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  self.fixture_table_names = []

  setup do
    @stakeholder_category = StakeholderCategory.create!(name: "Scoring Badge Stakeholder")
    @theme = Theme.create!(name: "Scoring Badge Theme", stakeholder_category: @stakeholder_category)
    @state = State.create!(name: "Scoring Badge State", code: "SBS")
    @district = District.create!(name: "Scoring Badge District", state: @state)
    @block = Block.create!(name: "Scoring Badge Block", district: @district)
    @unit = Unit.create!(name: "Scoring Badge Unit")

    @maker_employee = create_employee("Scoring Maker", "scoring.maker@example.com", "SCORE-MAKER")
    @member_pending = create_employee("Scoring Member Pending", "scoring.pending@example.com", "SCORE-PENDING")
    @member_done = create_employee("Scoring Member Done", "scoring.done@example.com", "SCORE-DONE")

    @maker_user = User.find_by!(email: @maker_employee.email_id)
    @pending_user = User.find_by!(email: @member_pending.email_id)
    @done_user = User.find_by!(email: @member_done.email_id)

    @quotation_proposal = build_scored_quotation_proposal!
  end

  test "committee member with unscored vendors sees the pending scoring badge" do
    sign_in @pending_user

    get quotation_proposal_url(@quotation_proposal)

    assert_response :success
    assert_select "span.app-link-label", text: "Committee Scoring"
    assert_select "span.text-bg-danger", text: "Your scoring is pending"
  end

  test "committee member who already scored every vendor sees no badge" do
    sign_in @done_user

    get quotation_proposal_url(@quotation_proposal)

    assert_response :success
    assert_select "span.app-link-label", text: "Committee Scoring", count: 0
    assert_select "span.text-bg-danger", text: "Your scoring is pending", count: 0
  end

  test "badge disappears once the member records their score" do
    @proposal_vendor.committee_member_scores.create!(employee_master: @member_pending, score: 8)

    sign_in @pending_user

    get quotation_proposal_url(@quotation_proposal)

    assert_response :success
    assert_select "span.app-link-label", text: "Committee Scoring", count: 0
    assert_select "span.text-bg-danger", text: "Your scoring is pending", count: 0
  end

  private

  def create_employee(name, email, employee_code)
    EmployeeMaster.create!(
      designation: "Committee Member",
      employee_code: employee_code,
      email_id: email,
      name: name,
      stakeholder_category: @stakeholder_category,
      user_type: "User"
    )
  end

  def build_scored_quotation_proposal!
    @vendor_registration = VendorRegistration.new(
      address: "Scoring badge address",
      block: @block,
      business_description: "Scoring badge business description",
      company_status: "Active",
      contact_person_designation: "Manager",
      contact_person_name: "Contact Person",
      district: @district,
      email: "vendor.scoring@example.com",
      firm_name: "Scoring Badge Vendor Firm",
      firm_type: "Company",
      mobile_no: "9700000011",
      pan_no: "ABCDE4321F",
      pin_no: "123458",
      stakeholder_category: @stakeholder_category,
      state: @state,
      submitted_at: Time.current,
      submitted_ip: "127.0.0.1",
      user: @maker_user,
      vendor_name: "Scoring Badge Vendor"
    )
    @vendor_registration.save!(validate: false)

    quotation_proposal = QuotationProposal.new(
      procurement_amount_bucket: "above_10k",
      proposal_end_date: Date.current + 7.days,
      remark: "Scoring badge remark",
      subject: "Scoring badge quotation proposal subject",
      theme: @theme,
      user: @maker_user,
      workflow_status: "committee_pending"
    )
    quotation_proposal.save!(validate: false)

    item = quotation_proposal.quotation_proposal_items.create!(
      item_name: "Scoring Badge Item",
      max_rate: 100,
      quantity: 5,
      remark: "Scoring badge item remark",
      unit: @unit
    )

    [@member_pending, @member_done].each_with_index do |member, index|
      quotation_proposal.committee_steps.create!(employee_master: member, level: index + 1, status: "waiting")
    end

    proposal_vendor = @proposal_vendor = quotation_proposal.quotation_proposal_vendors.create!(
      responded_at: Time.current,
      response_status: "responded",
      vendor_registration: @vendor_registration
    )
    proposal_vendor.vendor_items.create!(gst_percentage: 5, quotation_proposal_item: item, quoted_rate: 90)

    # Only one of the two committee members has recorded a score.
    proposal_vendor.committee_member_scores.create!(employee_master: @member_done, score: 7)

    create_approval_request_for!(quotation_proposal)

    quotation_proposal
  end

  # Committee members open a proposal through its approval request, so the
  # scoring page is only reachable once that request exists.
  def create_approval_request_for!(quotation_proposal)
    approval_channel = ApprovalChannel.new(
      approval_type: "Sequential",
      form_name: "Quotation Proposal",
      stakeholder_category: @stakeholder_category,
      theme: @theme
    )
    committee_actions = ["L1 Approval", "L2 Approval"]
    [@member_pending, @member_done].each_with_index do |member, index|
      approval_channel.approval_channel_steps.build(
        current_action: committee_actions[index],
        previous_action: index.zero? ? "NA" : committee_actions[index - 1],
        step_number: index + 1,
        to_responsible_user: member
      )
    end
    approval_channel.save!

    approval_request = ApprovalRequest.create!(
      approval_channel: approval_channel,
      approvable: quotation_proposal,
      current_level: 1,
      form_name: "Quotation Proposal",
      status: "approved"
    )
    [@member_pending, @member_done].each_with_index do |member, index|
      approval_request.approval_steps.create!(
        current_action: committee_actions[index],
        employee_master: member,
        level: index + 1,
        previous_action: index.zero? ? "NA" : committee_actions[index - 1],
        status: "approved"
      )
    end
    approval_request
  end
end
