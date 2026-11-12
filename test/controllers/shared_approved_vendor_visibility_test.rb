require "test_helper"

# Approved vendors are shared with every login, whichever maker or stakeholder
# registered them. Vendors still in approval stay with their maker and the
# approvers it has reached.
class SharedApprovedVendorVisibilityTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  self.fixture_table_names = []

  setup do
    @asa = StakeholderCategory.create!(name: "Shared ASA")
    @pgpl = StakeholderCategory.create!(name: "Shared PGPL")
    state = State.create!(name: "Shared State", code: "SHS")
    district = District.create!(name: "Shared District", state: state)
    @block = Block.create!(name: "Shared Block", district: district)
    [@asa, @pgpl].each do |stakeholder|
      %w[vendor_registration_list vendor_registration_main vendor_registration].each do |menu|
        MenuPermission.create!(stakeholder_category: stakeholder, designation: "Officer", menu_identifier: menu, can_view: true)
      end
    end

    @maker_a = create_employee("Maker A", "maker.a@example.com", "SH-A", @asa)
    @maker_b = create_employee("Maker B", "maker.b@example.com", "SH-B", @asa)
    @pgpl_user = create_employee("PGPL User", "pgpl.user@example.com", "SH-P", @pgpl)
    @finance = create_employee("Finance", "finance.sh@example.com", "SH-F", @asa)

    @approved = create_vendor("Approved Vendor Of A", "9811200001", @asa, status: "approved")
    @pending = create_vendor("Pending Vendor Of A", "9811200002", @asa, status: "pending")
    @pgpl_approved = create_vendor("Approved PGPL Vendor", "9811200003", @pgpl, status: "approved", owner: @pgpl_user)
  end

  test "another maker sees and opens every approved vendor, of any stakeholder" do
    sign_in user_for(@maker_b)

    get list_vendor_registrations_url
    assert_response :success
    listed = controller.instance_variable_get(:@vendor_registrations).to_a
    assert_includes listed, @approved
    assert_includes listed, @pgpl_approved
    assert_not_includes listed, @pending, "a vendor still in approval stays with its maker"

    get vendor_registration_url(@approved)
    assert_response :success
  end

  test "a pending vendor of another maker still cannot be opened" do
    sign_in user_for(@maker_b)

    get vendor_registration_url(@pending)
    assert_redirected_to list_vendor_registrations_path
  end

  test "a login of another stakeholder also sees and opens the approved vendor" do
    sign_in user_for(@pgpl_user)

    get list_vendor_registrations_url
    listed = controller.instance_variable_get(:@vendor_registrations).to_a
    assert_includes listed, @approved
    assert_not_includes listed, @pending

    get vendor_registration_url(@approved)
    assert_response :success
  end

  test "a quotation accepts a vendor of another stakeholder" do
    theme = Theme.create!(name: "Shared ASA Theme", stakeholder_category: @asa)
    quotation = QuotationProposal.new(theme: theme)
    quotation.vendor_registrations = [@pgpl_approved]
    quotation.valid?
    assert_not quotation.errors.full_messages.any? { |message| message.include?("same stakeholder") }
    assert quotation.vendor_matches_stakeholder?(@pgpl_approved)
  end

  test "the owner still sees both own vendors" do
    sign_in user_for(@maker_a)

    get list_vendor_registrations_url
    listed = controller.instance_variable_get(:@vendor_registrations).to_a
    assert_includes listed, @approved
    assert_includes listed, @pending
  end

  private

  def user_for(employee)
    User.find_by!(email: employee.email_id)
  end

  def create_employee(name, email, code, stakeholder)
    EmployeeMaster.create!(designation: "Officer", employee_code: code, email_id: email, name: name,
                           stakeholder_category: stakeholder, user_type: "User")
  end

  def create_vendor(name, mobile, stakeholder, status:, owner: @maker_a)
    vendor = VendorRegistration.new(address: "Addr", block: @block, district: @block.district, state: @block.district.state,
                                    email: "#{mobile}@example.com", firm_name: name, firm_type: "Company", mobile_no: mobile,
                                    pan_no: "ABCDE#{mobile.last(4)}F", pin_no: "123456", stakeholder_category: stakeholder,
                                    submitted_at: Time.current, submitted_ip: "127.0.0.1", user: user_for(owner), vendor_name: name)
    vendor.save!(validate: false)

    theme = Theme.find_or_create_by!(name: "Shared Theme #{stakeholder.name}", stakeholder_category: stakeholder)
    VendorRegistrationTheme.create!(vendor_registration: vendor, theme: theme)
    channel = ApprovalChannel.find_by(form_name: "Vendor Registration", stakeholder_category: stakeholder, theme: theme) ||
      ApprovalChannel.new(approval_type: "Sequential", form_name: "Vendor Registration", stakeholder_category: stakeholder, theme: theme).tap do |new_channel|
        new_channel.approval_channel_steps.build(current_action: "Finance Approval", previous_action: "NA", step_number: 1, to_responsible_user: @finance)
        new_channel.save!
      end
    request = ApprovalRequest.create!(approval_channel: channel, approvable: vendor, current_level: 1,
                                      form_name: "Vendor Registration", status: status)
    request.approval_steps.create!(current_action: "Finance Approval", employee_master: @finance, level: 1, previous_action: "NA",
                                   status: status == "approved" ? "approved" : "pending")
    vendor
  end
end
