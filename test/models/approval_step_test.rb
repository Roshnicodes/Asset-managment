require "test_helper"
require "ostruct"

class ApprovalStepTest < ActiveSupport::TestCase
  test "three approver sequential workflow shows recommended verify approved labels" do
    approval_request = build_sequential_request(approver_count: 3)

    assert_equal(
      ["Approved", "Recommended", "Verify", "Approved"],
      approval_request.approval_steps.sort_by(&:level).map(&:effective_status_label)
    )
  end

  test "two approver sequential workflow shows verify approved labels" do
    approval_request = build_sequential_request(approver_count: 2)

    assert_equal(
      ["Approved", "Verify", "Approved"],
      approval_request.approval_steps.sort_by(&:level).map(&:effective_status_label)
    )
  end

  test "parallel committee workflow keeps approved label for approved steps" do
    approval_request = build_parallel_committee_request

    assert_equal(
      ["Approved", "Approved", "Approved"],
      approval_request.approval_steps.sort_by(&:level).map(&:effective_status_label)
    )
  end

  test "non vendor sequential workflow keeps approved labels" do
    approval_request = build_non_vendor_sequential_request

    assert_equal(
      ["Approved", "Approved", "Approved"],
      approval_request.approval_steps.sort_by(&:level).map(&:effective_status_label)
    )
  end

  test "trail steps stay frozen to stored approval steps after channel changes" do
    approval_request = build_sequential_request(approver_count: 2)
    approval_request.approval_channel.define_singleton_method(:flow_steps) do
      [
        OpenStruct.new(step_number: 1, previous_action: "NA", current_action: "Proposal Create", to_responsible_user: nil, from_user: nil),
        OpenStruct.new(step_number: 2, previous_action: "Proposal Create", current_action: "Technical Approval", to_responsible_user: nil, from_user: nil),
        OpenStruct.new(step_number: 3, previous_action: "Technical Approval", current_action: "Managing Director", to_responsible_user: nil, from_user: nil),
        OpenStruct.new(step_number: 4, previous_action: "Managing Director", current_action: "Finance Approval", to_responsible_user: nil, from_user: nil)
      ]
    end

    assert_equal [1, 2, 3], approval_request.trail_steps.map(&:level)
  end

  test "existing sequential approval requests are not resynced from edited channels" do
    approval_request = build_sequential_request(approver_count: 2)
    original_levels = approval_request.approval_steps.map(&:level)

    approval_request.approval_channel.define_singleton_method(:flow_steps) do
      [
        OpenStruct.new(step_number: 1, previous_action: "NA", current_action: "Proposal Create", to_responsible_user: nil, from_user: nil),
        OpenStruct.new(step_number: 2, previous_action: "Proposal Create", current_action: "Technical Approval", to_responsible_user: nil, from_user: nil),
        OpenStruct.new(step_number: 3, previous_action: "Technical Approval", current_action: "Managing Director", to_responsible_user: nil, from_user: nil),
        OpenStruct.new(step_number: 4, previous_action: "Managing Director", current_action: "Finance Approval", to_responsible_user: nil, from_user: nil)
      ]
    end

    approval_request.ensure_channel_steps_synced!

    assert_equal original_levels, approval_request.approval_steps.map(&:level)
  end

  private

  def build_sequential_request(approver_count:)
    stakeholder = StakeholderCategory.new(name: "Operations")
    approval_request = ApprovalRequest.new(
      approval_channel: ApprovalChannel.new(form_name: "Vendor Registration", approval_type: "Sequential"),
      approvable: VendorRegistration.new(user: User.new(email: "maker@example.com")),
      status: "pending"
    )

    employees = [
      build_employee("Maker", "maker@example.com", stakeholder),
      build_employee("Approver 1", "approver1@example.com", stakeholder),
      build_employee("Approver 2", "approver2@example.com", stakeholder),
      build_employee("Approver 3", "approver3@example.com", stakeholder)
    ]

    approval_request.approval_steps.build(
      employee_master: employees[0],
      level: 1,
      status: "approved",
      previous_action: "NA",
      current_action: "Proposal Create"
    )

    approver_count.times do |index|
      approval_request.approval_steps.build(
        employee_master: employees[index + 1],
        level: index + 2,
        status: "approved",
        previous_action: index.zero? ? "Proposal Create" : "L#{index} Approved",
        current_action: "L#{index + 1} Approval"
      )
    end

    approval_request
  end

  def build_parallel_committee_request
    stakeholder = StakeholderCategory.new(name: "Operations")
    approval_request = ApprovalRequest.new(
      approval_channel: ApprovalChannel.new(form_name: "Quotation Proposal", approval_type: "Parallel"),
      approvable: QuotationProposal.new,
      status: "pending"
    )

    3.times do |index|
      approval_request.approval_steps.build(
        employee_master: build_employee("Committee #{index + 1}", "committee#{index + 1}@example.com", stakeholder),
        level: index + 1,
        status: "approved",
        previous_action: index.zero? ? "NA" : "L#{index} Approved",
        current_action: "L#{index + 1} Approval"
      )
    end

    approval_request
  end

  def build_non_vendor_sequential_request
    stakeholder = StakeholderCategory.new(name: "Operations")
    approval_request = ApprovalRequest.new(
      approval_channel: ApprovalChannel.new(form_name: "Product Entry", approval_type: "Sequential"),
      approvable: Product.new,
      status: "pending"
    )

    approval_request.approval_steps.build(
      employee_master: build_employee("Maker", "maker@example.com", stakeholder),
      level: 1,
      status: "approved",
      previous_action: "NA",
      current_action: "Proposal Create"
    )

    2.times do |index|
      approval_request.approval_steps.build(
        employee_master: build_employee("Approver #{index + 1}", "approver#{index + 1}@example.com", stakeholder),
        level: index + 2,
        status: "approved",
        previous_action: index.zero? ? "Proposal Create" : "L#{index} Approved",
        current_action: "L#{index + 1} Approval"
      )
    end

    approval_request
  end

  def build_employee(name, email, stakeholder)
    EmployeeMaster.new(
      name: name,
      employee_code: "EMP-#{email.split('@').first.parameterize.upcase}",
      email_id: email,
      user_type: "User",
      stakeholder_category: stakeholder
    )
  end
end
