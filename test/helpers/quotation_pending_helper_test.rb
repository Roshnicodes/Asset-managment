require "test_helper"

class QuotationPendingHelperTest < ActionView::TestCase
  tests QuotationPendingHelper
  self.fixture_table_names = []
  self.fixture_sets = {}
  self.fixture_class_names = {}

  def current_approval_employee_ids
    @current_approval_employee_ids || []
  end

  def current_user
    @current_user
  end

  def admin_user?
    false
  end

  setup do
    @stakeholder_category = StakeholderCategory.create!(name: "Pending Helper Stakeholder")
    @theme = Theme.create!(name: "Pending Helper Theme", stakeholder_category: @stakeholder_category)
    @state = State.create!(name: "Pending Helper State", code: "PHS")
    @district = District.create!(name: "Pending Helper District", state: @state)
    @block = Block.create!(name: "Pending Helper Block", district: @district)
    @unit = Unit.create!(name: "Pending Helper Unit")

    @maker_employee = create_employee("Pending Maker", "pending.maker@example.com", "PH-MAKER")
    @approver_employee = create_employee("Pending Approver", "pending.approver@example.com", "PH-APPROVER")
    @scorer_employee = create_employee("Pending Scorer", "pending.scorer@example.com", "PH-SCORER")

    @maker_user = User.find_by!(email: @maker_employee.email_id)
    @quotation_proposal = build_quotation_proposal!
  end

  test "approval pending counts against the quotation menu, not scoring" do
    build_approval_request!(status: "pending", step_status: "pending")
    @current_approval_employee_ids = [@approver_employee.id]

    assert_equal({ @quotation_proposal.id => :approval }, quotation_pending_actions)
    assert_equal 1, quotation_approval_pending_count
    assert_equal 0, quotation_scoring_pending_count
    assert_equal "Approval pending", quotation_pending_label(@quotation_proposal)
  end

  test "scoring pending counts against the scoring menu, not the quotation menu" do
    build_approval_request!(status: "approved", step_status: "approved")
    add_responded_vendor!
    @current_approval_employee_ids = [@scorer_employee.id]

    assert_equal({ @quotation_proposal.id => :scoring }, quotation_pending_actions)
    assert_equal 0, quotation_approval_pending_count
    assert_equal 1, quotation_scoring_pending_count
    assert_equal "Scoring pending", quotation_pending_label(@quotation_proposal)
  end

  test "a request returned to the maker is flagged for the maker only" do
    build_approval_request!(status: "returned", step_status: "returned", return_mode: "employee")
    @current_user = @maker_user
    @current_approval_employee_ids = [@maker_employee.id]

    assert_equal "Returned to you", quotation_pending_label(@quotation_proposal)
    assert_equal 1, quotation_approval_pending_count
    assert_equal 0, quotation_scoring_pending_count
  end

  test "a user with nothing waiting on them sees no pending work" do
    build_approval_request!(status: "approved", step_status: "approved")
    add_responded_vendor!
    @current_approval_employee_ids = [@approver_employee.id]

    assert_empty quotation_pending_actions
    assert_equal 0, quotation_approval_pending_count
    assert_equal 0, quotation_scoring_pending_count
    assert_nil quotation_pending_label(@quotation_proposal)
  end

  private

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

  def build_quotation_proposal!
    quotation_proposal = QuotationProposal.new(
      procurement_amount_bucket: "above_10k",
      proposal_end_date: Date.current + 7.days,
      remark: "Pending helper remark",
      subject: "Pending helper quotation subject",
      theme: @theme,
      user: @maker_user,
      workflow_status: "committee_pending"
    )
    quotation_proposal.save!(validate: false)

    @item = quotation_proposal.quotation_proposal_items.create!(
      item_name: "Pending Helper Item",
      max_rate: 100,
      quantity: 2,
      remark: "Pending helper item remark",
      unit: @unit
    )

    [@approver_employee, @scorer_employee].each_with_index do |member, index|
      quotation_proposal.committee_steps.create!(employee_master: member, level: index + 1, status: "waiting")
    end

    quotation_proposal
  end

  def add_responded_vendor!
    vendor_registration = VendorRegistration.new(
      address: "Pending helper address",
      block: @block,
      business_description: "Pending helper business description",
      company_status: "Active",
      contact_person_designation: "Manager",
      contact_person_name: "Contact Person",
      district: @district,
      email: "vendor.pending@example.com",
      firm_name: "Pending Helper Vendor Firm",
      firm_type: "Company",
      mobile_no: "9700000022",
      pan_no: "ABCDE8765F",
      pin_no: "123459",
      stakeholder_category: @stakeholder_category,
      state: @state,
      submitted_at: Time.current,
      submitted_ip: "127.0.0.1",
      user: @maker_user,
      vendor_name: "Pending Helper Vendor"
    )
    vendor_registration.save!(validate: false)

    proposal_vendor = @quotation_proposal.quotation_proposal_vendors.create!(
      responded_at: Time.current,
      response_status: "responded",
      vendor_registration: vendor_registration
    )
    proposal_vendor.vendor_items.create!(gst_percentage: 5, quotation_proposal_item: @item, quoted_rate: 90)
    # The approver has already scored; the scorer has not.
    proposal_vendor.committee_member_scores.create!(employee_master: @approver_employee, score: 6)
    proposal_vendor
  end

  def build_approval_request!(status:, step_status:, return_mode: nil)
    approval_channel = ApprovalChannel.new(
      approval_type: "Sequential",
      form_name: "Quotation Proposal",
      stakeholder_category: @stakeholder_category,
      theme: @theme
    )
    approval_channel.approval_channel_steps.build(
      current_action: "L1 Approval",
      previous_action: "NA",
      step_number: 1,
      to_responsible_user: @approver_employee
    )
    approval_channel.save!

    approval_request = ApprovalRequest.create!(
      approval_channel: approval_channel,
      approvable: @quotation_proposal,
      current_level: 1,
      form_name: "Quotation Proposal",
      status: status
    )
    approval_request.update_columns(return_mode: return_mode) if return_mode
    approval_request.approval_steps.create!(
      current_action: "L1 Approval",
      employee_master: @approver_employee,
      level: 1,
      previous_action: "NA",
      status: step_status
    )
    approval_request
  end
end
