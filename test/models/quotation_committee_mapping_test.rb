require "test_helper"

# Covers the predefined Quotation Committee mapped to a Head/Vertical, and the
# Vertical Head's option to skip the committee entirely.
class QuotationCommitteeMappingTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @stakeholder_category = StakeholderCategory.create!(name: "Mapping Stakeholder")
    @mapped_theme = Theme.create!(name: "Mapped Theme", stakeholder_category: @stakeholder_category)
    @unmapped_theme = Theme.create!(name: "Unmapped Theme", stakeholder_category: @stakeholder_category)

    @maker_employee = create_employee("Mapping Maker", "mapping.maker@example.com", "MAP-MAKER")
    @maker_user = User.find_by!(email: @maker_employee.email_id)
    @members = [
      create_employee("Mapping Member One", "mapping.one@example.com", "MAP-ONE"),
      create_employee("Mapping Member Two", "mapping.two@example.com", "MAP-TWO"),
      create_employee("Mapping Member Three", "mapping.three@example.com", "MAP-THREE")
    ]

    create_committee_channel!(@mapped_theme, @members)
  end

  test "the committee mapped to the head vertical is resolved from the theme" do
    members = QuotationProposal.configured_committee_members_for(@mapped_theme, user: @maker_user)

    assert_equal ["Mapping Member One", "Mapping Member Two", "Mapping Member Three"], members.map(&:name)
  end

  test "a proposal picks up the mapped committee without manual entry" do
    quotation_proposal = build_proposal(theme: @mapped_theme)

    assert quotation_proposal.apply_configured_committee!
    assert quotation_proposal.committee_from_configured_channel

    applied = quotation_proposal.committee_steps.reject(&:marked_for_destruction?)
    assert_equal [1, 2, 3], applied.map(&:level)
    assert_equal @members.map(&:id), applied.map(&:employee_master_id)
  end

  test "a theme without a mapping falls back to manual committee entry" do
    quotation_proposal = build_proposal(theme: @unmapped_theme)

    assert_not quotation_proposal.apply_configured_committee!
    assert_not quotation_proposal.committee_from_configured_channel
    assert_empty quotation_proposal.committee_steps.reject(&:marked_for_destruction?)
  end

  test "sharing directly with the vendor drops the committee and skips its validations" do
    quotation_proposal = build_proposal(theme: @mapped_theme, committee_approval_required: false)
    quotation_proposal.committee_steps.build(employee_master: @members.first, level: 1, status: "waiting")

    assert quotation_proposal.apply_configured_committee!
    assert_empty quotation_proposal.committee_steps.reject(&:marked_for_destruction?)
    assert quotation_proposal.committee_not_required?
    assert quotation_proposal.committee_completed?

    quotation_proposal.validate
    assert_empty quotation_proposal.errors[:base].grep(/Committee/)
  end

  test "a mapped committee is not held to the manual minimum level rules" do
    short_theme = Theme.create!(name: "Short Committee Theme", stakeholder_category: @stakeholder_category)
    create_committee_channel!(short_theme, [@members.first])

    quotation_proposal = build_proposal(theme: short_theme)
    assert quotation_proposal.apply_configured_committee!

    quotation_proposal.validate
    assert_empty quotation_proposal.errors[:base].grep(/levels bina gap/)
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

  def create_committee_channel!(theme, members)
    actions = ["L1 Approval", "L2 Approval", "L3 Approval"]
    channel = ApprovalChannel.new(
      approval_type: "Sequential",
      form_name: "Quotation Proposal",
      stakeholder_category: @stakeholder_category,
      theme: theme
    )
    members.each_with_index do |member, index|
      channel.approval_channel_steps.build(
        current_action: actions[index],
        previous_action: index.zero? ? "NA" : actions[index - 1],
        step_number: index + 1,
        to_responsible_user: member
      )
    end
    channel.save!
    channel
  end

  def build_proposal(theme:, committee_approval_required: true)
    QuotationProposal.new(
      committee_approval_required: committee_approval_required,
      procurement_amount_bucket: "above_10k",
      proposal_end_date: Date.current + 7.days,
      remark: "Mapping remark",
      subject: "Mapped committee quotation subject",
      theme: theme,
      user: @maker_user
    )
  end
end
