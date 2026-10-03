require "test_helper"

# Once a quotation is approved the maker can no longer change it, but an admin
# can still correct it. The approved committee stays locked on the form.
class AdminApprovedQuotationEditTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  self.fixture_table_names = []

  setup do
    @stakeholder_category = StakeholderCategory.create!(name: "Admin Edit Stakeholder")
    @theme = Theme.create!(name: "Admin Edit Theme", stakeholder_category: @stakeholder_category)
    @unit = Unit.create!(name: "Admin Edit Unit")

    @maker = create_employee("Admin Edit Maker", "admin.edit.maker@example.com", "AE-MAKER", "User")
    @admin = create_employee("Admin Edit Admin", "admin.edit.admin@example.com", "AE-ADMIN", "Admin")
    @members = [
      create_employee("Admin Edit One", "admin.edit.one@example.com", "AE-ONE", "User"),
      create_employee("Admin Edit Two", "admin.edit.two@example.com", "AE-TWO", "User"),
      create_employee("Admin Edit Three", "admin.edit.three@example.com", "AE-THREE", "User")
    ]

    @quotation_proposal = build_approved_proposal!
  end

  test "admin sees the edit action and a locked committee on an approved quotation" do
    sign_in User.find_by!(email: @admin.email_id)

    get list_quotation_proposals_url
    assert_select "a[href=?]", edit_quotation_proposal_path(@quotation_proposal)

    get edit_quotation_proposal_url(@quotation_proposal)
    assert_response :success
    assert_match "approval committee below is locked", response.body
    assert_select "[data-committee-member-search]", count: 0
  end

  test "maker cannot edit an approved quotation" do
    sign_in User.find_by!(email: @maker.email_id)

    get edit_quotation_proposal_url(@quotation_proposal)
    assert_response :redirect
  end

  private

  def create_employee(name, email, employee_code, user_type)
    EmployeeMaster.create!(
      designation: "Officer",
      employee_code: employee_code,
      email_id: email,
      name: name,
      stakeholder_category: @stakeholder_category,
      user_type: user_type
    )
  end

  def build_approved_proposal!
    quotation_proposal = QuotationProposal.new(
      procurement_amount_bucket: "above_10k",
      proposal_end_date: Date.current + 7.days,
      remark: "Admin edit remark",
      subject: "Admin edit approved quotation subject",
      theme: @theme,
      user: User.find_by!(email: @maker.email_id),
      workflow_status: "committee_approved"
    )
    quotation_proposal.save!(validate: false)
    quotation_proposal.quotation_proposal_items.create!(item_name: "Admin Edit Item", max_rate: 100, quantity: 2, remark: "Item remark", unit: @unit)

    channel = ApprovalChannel.new(approval_type: "Sequential", form_name: "Quotation Proposal", stakeholder_category: @stakeholder_category, theme: @theme)
    request = nil
    @members.each_with_index do |member, index|
      level = index + 1
      channel.approval_channel_steps.build(current_action: "L#{level} Approval", previous_action: level == 1 ? "NA" : "L#{level - 1} Approval", step_number: level, to_responsible_user: member)
    end
    channel.save!

    request = ApprovalRequest.create!(approval_channel: channel, approvable: quotation_proposal, form_name: "Quotation Proposal", status: "approved")
    @members.each_with_index do |member, index|
      level = index + 1
      quotation_proposal.committee_steps.create!(employee_master: member, level: level, status: "approved")
      request.approval_steps.create!(current_action: "L#{level} Approval", employee_master: member, level: level, previous_action: level == 1 ? "NA" : "L#{level - 1} Approval", status: "approved")
    end

    quotation_proposal
  end
end
