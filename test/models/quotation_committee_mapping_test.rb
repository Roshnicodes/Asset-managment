require "test_helper"

# Covers the committee policy for existing quotations without a Thematic Head:
# the maker picks the 1st member, the 2nd is the COO (estimated value up to
# ₹10 lakh) or the Director (above), and the 3rd is always the Programme
# Director – Finance.
class QuotationCommitteeMappingTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @stakeholder_category = StakeholderCategory.create!(name: "Policy Stakeholder")
    @theme = Theme.create!(name: "Policy Theme", stakeholder_category: @stakeholder_category)

    @maker_employee = create_employee("Policy Maker", "policy.maker@example.com", "POL-MAKER", "Program Manager")
    @maker_user = User.find_by!(email: @maker_employee.email_id)
    @first_member = create_employee("Policy First", "policy.first@example.com", "POL-FIRST", "Program Manager")
    @coo = create_employee("Policy COO", "policy.coo@example.com", "POL-COO", "COO")
    @director = create_employee("Policy Director", "policy.director@example.com", "POL-DIR", "Director")
    @finance = create_employee("Policy Finance", "policy.finance@example.com", "POL-FIN", "Programme Director - Finance")
  end

  test "value up to 10 lakh routes the 2nd member to the COO" do
    quotation_proposal = build_proposal(quantity: 10, max_rate: 100_000)

    assert quotation_proposal.apply_configured_committee!
    assert_equal [@first_member, @coo, @finance].map(&:id), kept_member_ids(quotation_proposal)
  end

  test "value above 10 lakh routes the 2nd member to the Director" do
    quotation_proposal = build_proposal(quantity: 10, max_rate: 100_001)

    assert quotation_proposal.apply_configured_committee!
    assert_equal [@first_member, @director, @finance].map(&:id), kept_member_ids(quotation_proposal)
  end

  test "policy members overwrite crafted values for levels 2 and 3" do
    quotation_proposal = build_proposal(quantity: 1, max_rate: 500)
    quotation_proposal.committee_steps.build(level: 2, employee_master: @first_member, status: "waiting")
    quotation_proposal.committee_steps.build(level: 4, employee_master: @director, status: "waiting")

    assert quotation_proposal.apply_configured_committee!
    assert_equal [@first_member, @coo, @finance].map(&:id), kept_member_ids(quotation_proposal)
  end

  test "the 1st member is mandatory" do
    quotation_proposal = build_proposal(quantity: 1, max_rate: 500, first_member: nil)

    assert_not quotation_proposal.apply_configured_committee!
    quotation_proposal.validate
    assert_includes quotation_proposal.errors[:base], "Select the 1st Committee Member."
  end

  test "the 1st member cannot repeat a policy member" do
    quotation_proposal = build_proposal(quantity: 1, max_rate: 500, first_member: @finance)

    quotation_proposal.apply_configured_committee!
    quotation_proposal.validate
    assert_includes quotation_proposal.errors[:base], "Committee members must be unique."
  end

  test "policy directory exposes the configured members for the form" do
    directory = QuotationProposal.committee_policy_directory

    assert_equal 1_000_000, directory[:threshold]
    assert_equal @coo.id, directory[:coo][:id]
    assert_equal @director.id, directory[:director][:id]
    assert_equal @finance.id, directory[:finance][:id]
  end

  test "a new quotation without a Thematic Head gets the policy committee" do
    quotation_proposal = QuotationProposal.new(theme: @theme, user: @maker_user, committee_approval_required: true)
    quotation_proposal.quotation_proposal_items.build(item_name: "Policy item", quantity: 1, max_rate: 500)
    quotation_proposal.committee_steps.build(level: 1, employee_master: @first_member, status: "waiting")

    assert quotation_proposal.apply_configured_committee!
    assert_equal [@first_member, @coo, @finance].map(&:id), kept_member_ids(quotation_proposal)
  end

  test "a quotation with a Thematic Head leaves the committee to the head" do
    head = create_employee("Policy Head", "policy.head@example.com", "POL-HEAD", "Program Manager")
    quotation_proposal = QuotationProposal.new(theme: @theme, user: @maker_user, committee_approval_required: true, thematic_head: head)
    quotation_proposal.committee_steps.build(level: 1, employee_master: @first_member, status: "waiting")

    assert quotation_proposal.apply_configured_committee!
    assert_equal [@first_member.id], quotation_proposal.committee_steps.map(&:employee_master_id)
  end

  test "sharing directly with the vendor drops the committee and skips its validations" do
    quotation_proposal = build_proposal(quantity: 1, max_rate: 500, committee_approval_required: false)

    assert quotation_proposal.apply_configured_committee!
    assert_empty quotation_proposal.committee_steps.reject(&:marked_for_destruction?)
    assert quotation_proposal.committee_completed?

    quotation_proposal.validate
    assert_empty quotation_proposal.errors[:base].grep(/Committee/)
  end

  private

  def kept_member_ids(quotation_proposal)
    quotation_proposal.committee_steps.reject(&:marked_for_destruction?).sort_by(&:level).map(&:employee_master_id)
  end

  def create_employee(name, email, employee_code, designation)
    EmployeeMaster.create!(
      designation: designation,
      employee_code: employee_code,
      email_id: email,
      name: name,
      stakeholder_category: @stakeholder_category,
      user_type: "User"
    )
  end

  def build_proposal(quantity:, max_rate:, first_member: @first_member, committee_approval_required: true)
    quotation_proposal = QuotationProposal.new(
      committee_approval_required: committee_approval_required,
      procurement_amount_bucket: "above_10k",
      proposal_end_date: Date.current + 7.days,
      remark: "Policy remark",
      subject: "Committee policy quotation subject",
      theme: @theme,
      user: @maker_user
    )
    quotation_proposal.quotation_proposal_items.build(item_name: "Policy item", quantity: quantity, max_rate: max_rate)
    quotation_proposal.committee_steps.build(level: 1, employee_master: first_member, status: "waiting") if first_member
    quotation_proposal
  end
end
