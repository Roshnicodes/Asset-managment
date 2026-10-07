require "test_helper"

# An approver should only see a request once it has reached them: pending on
# their level now, or already actioned by them. A later-level approver must not
# see it while an earlier level is still deciding.
class ApprovalVisibilityTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  self.fixture_table_names = []

  setup do
    @stakeholder_category = StakeholderCategory.create!(name: "Visibility Stakeholder")
    @theme = Theme.create!(name: "Visibility Theme", stakeholder_category: @stakeholder_category)
    @state = State.create!(name: "Visibility State", code: "VIS")
    @district = District.create!(name: "Visibility District", state: @state)
    @block = Block.create!(name: "Visibility Block", district: @district)

    @creator = create_employee("Visibility Creator", "visibility.creator@example.com", "VIS-CREATOR")
    @first_approver = create_employee("Visibility First", "visibility.first@example.com", "VIS-FIRST")
    @second_approver = create_employee("Visibility Second", "visibility.second@example.com", "VIS-SECOND")

    @vendor_registration = build_vendor_registration
    @approval_request = create_two_level_request!(@vendor_registration)
  end

  test "pending list shows the request only to the approver it is waiting on" do
    sign_in user_for(@first_approver)
    get approval_requests_url(status: "pending")
    assert_response :success
    assert_includes controller.instance_variable_get(:@pending_approval_requests).to_a, @approval_request

    sign_out :user
    sign_in user_for(@second_approver)
    get approval_requests_url(status: "all")
    assert_response :success
    assert_not_includes controller.instance_variable_get(:@pending_approval_requests).to_a, @approval_request
    assert_not_includes controller.instance_variable_get(:@processed_approval_requests).to_a, @approval_request
  end

  test "a later approver cannot open or list the record before it reaches them" do
    sign_in user_for(@second_approver)

    get vendor_registration_url(@vendor_registration)
    assert_redirected_to root_path

    get list_vendor_registrations_url
    assert_not_includes Array(controller.instance_variable_get(:@vendor_registrations)), @vendor_registration
  end

  test "the request appears for the next approver once the earlier level approves" do
    @approval_request.approve!(employee: @first_approver, remark: "OK")

    sign_in user_for(@second_approver)
    get approval_requests_url(status: "pending")
    assert_includes controller.instance_variable_get(:@pending_approval_requests).to_a, @approval_request

    sign_out :user
    sign_in user_for(@first_approver)
    get approval_requests_url(status: "pending")
    assert_not_includes controller.instance_variable_get(:@pending_approval_requests).to_a, @approval_request
  end

  test "a request returned before reaching an approver stays hidden from them" do
    @approval_request.return_to_employee!(employee: @first_approver, remark: "Fix details")

    sign_in user_for(@second_approver)
    get approval_requests_url(status: "returned")
    assert_not_includes controller.instance_variable_get(:@processed_approval_requests).to_a, @approval_request

    sign_out :user
    sign_in user_for(@first_approver)
    get approval_requests_url(status: "returned")
    assert_includes controller.instance_variable_get(:@processed_approval_requests).to_a, @approval_request
  end

  test "the approver gets Approve, Return and Reject from the list and the detail page" do
    sign_in user_for(@first_approver)

    get approval_requests_url(status: "pending")
    assert_response :success
    assert_select ".appr-stat strong", text: "1"
    assert_select "tr.is-mine .appr-ref", text: format("VEN-%03d", @vendor_registration.id)
    assert_select "[data-appr-menu] [data-approval-popup-open='approve-approval-request-#{@approval_request.id}']"
    assert_select "[data-appr-menu] [data-approval-popup-open='return-approval-request-#{@approval_request.id}']"
    assert_select "[data-appr-menu] [data-approval-popup-open='reject-approval-request-#{@approval_request.id}']"
    assert_select "form[action='#{approve_approval_request_path(@approval_request)}']"

    get vendor_registration_url(@vendor_registration)
    assert_response :success
    assert_select "h2", /Vendor Registration Details/
    assert_select ".vd-action-card form[action='#{approve_approval_request_path(@approval_request)}']"
    assert_select "[data-vd-tab]", 5
  end

  private

  def user_for(employee)
    User.find_by!(email: employee.email_id)
  end

  def create_employee(name, email, employee_code)
    EmployeeMaster.create!(
      designation: "Approver",
      employee_code: employee_code,
      email_id: email,
      name: name,
      stakeholder_category: @stakeholder_category,
      user_type: "User"
    )
  end

  def build_vendor_registration
    vendor_registration = VendorRegistration.new(
      address: "Visibility address",
      block: @block,
      business_description: "Visibility business description",
      company_status: "Active",
      contact_person_designation: "Manager",
      contact_person_name: "Contact Person",
      district: @district,
      email: "vendor.visibility@example.com",
      firm_name: "Visibility Vendor Firm",
      firm_type: "Company",
      mobile_no: "9811122299",
      pan_no: "ABCDE1299F",
      pin_no: "123499",
      stakeholder_category: @stakeholder_category,
      state: @state,
      submitted_at: Time.current,
      submitted_ip: "127.0.0.1",
      user: user_for(@creator),
      vendor_name: "Visibility Vendor"
    )
    vendor_registration.save!(validate: false)
    vendor_registration
  end

  def create_two_level_request!(approvable)
    approval_channel = ApprovalChannel.new(
      approval_type: "Sequential",
      form_name: "Vendor Registration",
      stakeholder_category: @stakeholder_category,
      theme: @theme
    )
    approval_channel.approval_channel_steps.build(current_action: "L1 Approval", previous_action: "NA", step_number: 1, to_responsible_user: @first_approver)
    approval_channel.approval_channel_steps.build(current_action: "L2 Approval", previous_action: "L1 Approval", step_number: 2, to_responsible_user: @second_approver)
    approval_channel.save!

    approval_request = ApprovalRequest.create!(
      approval_channel: approval_channel,
      approvable: approvable,
      current_level: 1,
      form_name: "Vendor Registration",
      status: "pending"
    )
    approval_request.approval_steps.create!(current_action: "L1 Approval", employee_master: @first_approver, level: 1, previous_action: "NA", status: "pending")
    approval_request.approval_steps.create!(current_action: "L2 Approval", employee_master: @second_approver, level: 2, previous_action: "L1 Approval", status: "waiting")
    approval_request
  end
end
