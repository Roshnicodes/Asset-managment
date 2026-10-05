require "test_helper"

# The maker picks a Thematic Head. Sending the request goes to that head, who
# chooses With Committee (committee approval workflow) or Without Committee
# (quotation link sent straight to the vendors).
class ThematicHeadDecisionTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  self.fixture_table_names = []

  setup do
    @stakeholder_category = StakeholderCategory.create!(name: "Head Decision Stakeholder")
    @theme = Theme.create!(name: "Head Decision Theme", stakeholder_category: @stakeholder_category)
    @state = State.create!(name: "Head Decision State", code: "HDS")
    @district = District.create!(name: "Head Decision District", state: @state)
    @block = Block.create!(name: "Head Decision Block", district: @district)
    @unit = Unit.create!(name: "Head Decision Unit")

    @maker = create_employee("Head Maker", "head.maker@example.com", "HD-MAKER", "Admin")
    @head = create_employee("Thematic Head", "thematic.head@example.com", "HD-HEAD", "User")
    @other = create_employee("Someone Else", "someone.else@example.com", "HD-OTHER", "User")
    @first_member = create_employee("Committee One", "committee.one@example.com", "HD-ONE", "User")
    @coo = create_employee("Policy COO", "policy.coo@example.com", "HD-COO", "User", designation: "COO")
    @director = create_employee("Policy Director", "policy.director@example.com", "HD-DIR", "User", designation: "Director")
    @finance = create_employee("Policy Finance", "policy.finance@example.com", "HD-FIN", "User", designation: "Programme Director - Finance")

    @quotation_proposal = build_proposal
  end

  test "sending the request goes to the thematic head first" do
    sign_in user_for(@maker)

    post send_for_approval_quotation_proposal_url(@quotation_proposal)

    @quotation_proposal.reload
    assert @quotation_proposal.awaiting_thematic_head_decision?
    assert_equal "thematic_head_pending", @quotation_proposal.workflow_status
    assert_nil @quotation_proposal.approval_request
    assert Notification.exists?(user: user_for(@head), notifiable: @quotation_proposal)
  end

  test "With Committee: the head picks the 1st member and the policy adds COO/Director and Finance" do
    @quotation_proposal.request_thematic_head_decision!
    sign_in user_for(@head)

    get quotation_proposal_url(@quotation_proposal)
    assert_response :success
    assert_select "button[name=decision][value=committee]", text: "With Committee"
    assert_select "button[name=decision][value=direct]", text: "Without Committee"
    assert_select "input[data-employee-picker-search][list=thematic-head-committee-options]", count: 1
    assert_select ".quotation-thematic-head-policy li", text: /Policy COO/
    assert_select ".quotation-thematic-head-policy li", text: /Policy Finance/

    post thematic_head_decision_quotation_proposal_url(@quotation_proposal),
         params: { decision: "committee", first_member_id: @first_member.id }

    @quotation_proposal.reload
    assert_equal "committee", @quotation_proposal.thematic_head_decision
    assert @quotation_proposal.committee_approval_required?
    expected = [@first_member.id, @coo.id, @finance.id]
    assert_equal expected, @quotation_proposal.committee_steps.order(:level).map(&:employee_master_id)
    assert_equal expected, @quotation_proposal.approval_request.approval_steps.order(:level).map(&:employee_master_id)
  end

  test "With Committee needs a valid 1st member who is not a policy member" do
    @quotation_proposal.request_thematic_head_decision!
    sign_in user_for(@head)

    post thematic_head_decision_quotation_proposal_url(@quotation_proposal), params: { decision: "committee", first_member_id: "" }
    assert_equal "Please pick the 1st Committee Member from the suggestions list.", flash[:alert]

    post thematic_head_decision_quotation_proposal_url(@quotation_proposal), params: { decision: "committee", first_member_id: @finance.id }
    assert_match "Committee members must be unique", flash[:alert]

    @quotation_proposal.reload
    assert_nil @quotation_proposal.thematic_head_decision
    assert_nil @quotation_proposal.approval_request
    assert_empty @quotation_proposal.committee_steps
  end

  test "Without Committee builds the committee but sends the link to the vendors right away" do
    @quotation_proposal.request_thematic_head_decision!
    sign_in user_for(@head)

    sent_to = []
    QuotationVendorSmsGateway.stub(:send_vendor_link, ->(dispatch, mobile_no: dispatch.mobile_no) { sent_to << mobile_no; true }) do
      post thematic_head_decision_quotation_proposal_url(@quotation_proposal), params: { decision: "direct", first_member_id: @first_member.id }
    end

    @quotation_proposal.reload
    assert_equal "direct", @quotation_proposal.thematic_head_decision
    assert_not @quotation_proposal.committee_approval_required?
    assert_nil @quotation_proposal.approval_request, "no approval before sending"
    assert_equal [@first_member.id, @coo.id, @finance.id], @quotation_proposal.committee_steps.order(:level).map(&:employee_master_id)
    assert @quotation_proposal.committee_reviews_responses?, "the committee reviews the vendor quotations"
    assert @quotation_proposal.sent_to_vendors_at.present?
    assert_includes sent_to, "9700000081"
  end

  test "after Without Committee the committee can open the quotation to review responses" do
    @quotation_proposal.request_thematic_head_decision!
    QuotationVendorSmsGateway.stub(:send_vendor_link, ->(*_args, **_kwargs) { true }) do
      @quotation_proposal.record_thematic_head_decision!("direct", first_member_id: @first_member.id)
      @quotation_proposal.send_to_vendors!
    end

    sign_in user_for(@coo)
    get quotation_proposal_url(@quotation_proposal)
    assert_response :success

    MenuPermission.create!(stakeholder_category: @stakeholder_category, designation: "COO", menu_identifier: "quotation_proposal_list", can_view: true)
    get list_quotation_proposals_url
    assert_response :success, flash[:alert].to_s
    assert_includes controller.instance_variable_get(:@quotation_proposals).to_a, @quotation_proposal
  end

  test "Without Committee also needs the 1st member" do
    @quotation_proposal.request_thematic_head_decision!
    sign_in user_for(@head)

    post thematic_head_decision_quotation_proposal_url(@quotation_proposal), params: { decision: "direct", first_member_id: "" }

    assert_equal "Please pick the 1st Committee Member from the suggestions list.", flash[:alert]
    assert_nil @quotation_proposal.reload.sent_to_vendors_at
  end

  test "the maker can resend after Without Committee" do
    @quotation_proposal.request_thematic_head_decision!
    QuotationVendorSmsGateway.stub(:send_vendor_link, ->(*_args, **_kwargs) { true }) do
      @quotation_proposal.record_thematic_head_decision!("direct", first_member_id: @first_member.id)
    end
    sign_in user_for(@maker)

    QuotationVendorSmsGateway.stub(:send_vendor_link, ->(*_args, **_kwargs) { true }) do
      post send_to_vendors_quotation_proposal_url(@quotation_proposal)
    end

    assert @quotation_proposal.reload.sent_to_vendors_at.present?
  end

  test "someone else cannot send the quotation to the vendors" do
    @quotation_proposal.request_thematic_head_decision!
    QuotationVendorSmsGateway.stub(:send_vendor_link, ->(*_args, **_kwargs) { true }) do
      @quotation_proposal.record_thematic_head_decision!("direct", first_member_id: @first_member.id)
    end
    sign_in user_for(@other)

    post send_to_vendors_quotation_proposal_url(@quotation_proposal)

    assert_nil @quotation_proposal.reload.sent_to_vendors_at
  end

  test "only the selected thematic head can decide" do
    @quotation_proposal.request_thematic_head_decision!
    sign_in user_for(@other)

    post thematic_head_decision_quotation_proposal_url(@quotation_proposal, decision: "direct")

    assert_nil @quotation_proposal.reload.thematic_head_decision
  end

  test "the new quotation form asks the maker for a thematic head" do
    sign_in user_for(@maker)

    get new_quotation_proposal_url

    assert_response :success
    assert_select "input[data-employee-picker-search][list=thematic-head-options]"
    assert_select "input[type=hidden][name='quotation_proposal[thematic_head_id]']"
    assert_select "select[name='quotation_proposal[committee_approval_required]']", count: 0
  end

  test "without a Thematic Head the maker's committee follows the normal approval process" do
    quotation_proposal = build_proposal
    quotation_proposal.update_columns(thematic_head_id: nil)
    [@first_member, @coo, @finance].each_with_index do |member, index|
      quotation_proposal.committee_steps.create!(employee_master: member, level: index + 1, status: "waiting")
    end
    sign_in user_for(@maker)

    post send_for_approval_quotation_proposal_url(quotation_proposal)

    quotation_proposal.reload
    assert_nil quotation_proposal.thematic_head_requested_at
    assert quotation_proposal.approval_request.present?
    assert_equal [@first_member.id, @coo.id, @finance.id], quotation_proposal.approval_request.approval_steps.order(:level).map(&:employee_master_id)
  end

  private

  def user_for(employee)
    User.find_by!(email: employee.email_id)
  end

  def create_employee(name, email, employee_code, user_type, designation: "Officer")
    EmployeeMaster.create!(
      designation: designation,
      employee_code: employee_code,
      email_id: email,
      name: name,
      stakeholder_category: @stakeholder_category,
      user_type: user_type
    )
  end

  def build_proposal
    quotation_proposal = QuotationProposal.new(
      procurement_amount_bucket: "above_10k",
      proposal_end_date: Date.current + 7.days,
      remark: "Head decision remark",
      subject: "Head decision quotation subject words",
      theme: @theme,
      thematic_head: @head,
      user: user_for(@maker)
    )
    quotation_proposal.save!(validate: false)
    quotation_proposal.quotation_proposal_items.create!(item_name: "Laptop", max_rate: 100, quantity: 2, remark: "Item remark", unit: @unit)

    vendor_registration = VendorRegistration.new(
      address: "Head decision address",
      block: @block,
      business_description: "Head decision business description",
      company_status: "Active",
      contact_person_designation: "Manager",
      contact_person_name: "Contact Person",
      district: @district,
      email: "head.decision.vendor@example.com",
      firm_name: "Head Decision Firm",
      firm_type: "Company",
      mobile_no: "9700000081",
      pan_no: "ABCDE1381F",
      pin_no: "123483",
      stakeholder_category: @stakeholder_category,
      state: @state,
      submitted_at: Time.current,
      submitted_ip: "127.0.0.1",
      user: user_for(@maker),
      vendor_name: "Head Decision Vendor"
    )
    vendor_registration.save!(validate: false)
    quotation_proposal.quotation_proposal_vendors.create!(vendor_registration: vendor_registration)
    quotation_proposal.reload
  end
end
