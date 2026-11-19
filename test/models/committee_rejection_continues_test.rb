require "test_helper"

# Quotation committee: one member's rejection no longer ends the approval.
# The others still give their decision and are told who rejected and why;
# once everyone has decided, any rejection rejects the quotation.
class CommitteeRejectionContinuesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  self.fixture_table_names = []

  setup do
    @stakeholder = StakeholderCategory.create!(name: "Committee Rule Stakeholder")
    @theme = Theme.create!(name: "Committee Rule Theme", stakeholder_category: @stakeholder)
    @maker = employee("Committee Maker", "committee.maker@example.com", "CR-MAKER")
    @l1 = employee("Committee L1", "committee.l1@example.com", "CR-L1")
    @l2 = employee("Committee L2", "committee.l2@example.com", "CR-L2")
    @l3 = employee("Committee L3", "committee.l3@example.com", "CR-L3")

    @quotation = QuotationProposal.new(procurement_amount_bucket: "above_10k", proposal_end_date: Date.current + 7.days,
                                       remark: "Committee rule", subject: "Committee rule quotation proposal for the test",
                                       theme: @theme, user: user_for(@maker), workflow_status: "committee_pending")
    @quotation.save!(validate: false)
    [@l1, @l2, @l3].each_with_index do |member, index|
      @quotation.committee_steps.create!(level: index + 1, employee_master: member, status: "pending")
    end

    channel = ApprovalChannel.new(approval_type: "Sequential", form_name: "Quotation Proposal", stakeholder_category: @stakeholder, theme: @theme)
    channel.approval_channel_steps.build(current_action: "L1 Approval", previous_action: "NA", step_number: 1, to_responsible_user: @l1)
    channel.save!
    @approval = ApprovalRequest.create!(approval_channel: channel, approvable: @quotation, current_level: 1,
                                       form_name: "Quotation Proposal", status: "pending")
    [@l1, @l2, @l3].each_with_index do |member, index|
      level = index + 1
      @approval.approval_steps.create!(current_action: "L#{level} Approval", employee_master: member, level: level,
                                      previous_action: level == 1 ? "NA" : "L#{level - 1} Approval", status: "pending")
    end
  end

  test "after L1 rejects, the others can still decide and are told the reason" do
    assert_difference -> { Notification.where(user: [user_for(@l2), user_for(@l3), user_for(@maker)]).count }, 3 do
      @approval.reject!(employee: @l1, remark: "Double proposal entry")
    end

    @approval.reload
    assert_equal "pending", @approval.status
    assert_equal %w[rejected pending pending], @approval.approval_steps.order(:level).pluck(:status)

    note = Notification.where(user: user_for(@l2)).order(:id).last
    assert_match "Rejected by Committee L1", note.title
    assert_match "Reason: Double proposal entry", note.message
  end

  test "once everyone has decided, a rejection rejects the quotation" do
    @approval.reject!(employee: @l1, remark: "Double proposal entry")
    @approval.reload.approve!(employee: @l2, remark: "OK")
    assert_equal "pending", @approval.reload.status

    @approval.approve!(employee: @l3, remark: "OK")
    @approval.reload
    assert_equal "rejected", @approval.status
    assert_equal %w[rejected approved approved], @approval.approval_steps.order(:level).pluck(:status)

    maker_note = Notification.where(user: user_for(@maker)).order(:id).last
    assert_match "Committee L1: Double proposal entry", maker_note.message
  end

  test "all approvals still approve the quotation" do
    [@l1, @l2, @l3].each { |member| @approval.reload.approve!(employee: member, remark: "OK") }
    assert_equal "approved", @approval.reload.status
  end

  test "a return still goes straight back to the maker" do
    @approval.return_to_employee!(employee: @l2, remark: "Fix the items")
    assert_equal "returned", @approval.reload.status
  end

  test "the member who rejected finds it under Rejected while others decide" do
    @approval.reject!(employee: @l1, remark: "Double proposal entry")

    sign_in user_for(@l1)
    get approval_requests_url(status: "rejected")
    assert_response :success
    assert_includes controller.instance_variable_get(:@processed_approval_requests).to_a, @approval

    sign_out :user
    sign_in user_for(@l2)
    get approval_requests_url(status: "pending")
    assert_includes controller.instance_variable_get(:@pending_approval_requests).to_a, @approval
  end

  private

  def employee(name, email, code)
    EmployeeMaster.create!(designation: "Officer", employee_code: code, email_id: email, name: name,
                           stakeholder_category: @stakeholder, user_type: "User")
  end

  def user_for(employee)
    User.find_by!(email: employee.email_id)
  end
end
