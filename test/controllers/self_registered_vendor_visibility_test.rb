require "test_helper"

# A vendor who registers from the public /vr page belongs to no maker. The
# Vendor Registration makers of the same stakeholder and theme still see it.
class SelfRegisteredVendorVisibilityTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  self.fixture_table_names = []

  setup do
    @stakeholder = StakeholderCategory.create!(name: "Self Reg Stakeholder")
    @agriculture = Theme.create!(name: "Self Reg Agriculture", stakeholder_category: @stakeholder)
    @water = Theme.create!(name: "Self Reg Water", stakeholder_category: @stakeholder)
    state = State.create!(name: "Self Reg State", code: "SRS")
    district = District.create!(name: "Self Reg District", state: state)
    @block = Block.create!(name: "Self Reg Block", district: district)

    @agri_maker = create_employee("Agri Maker", "agri.maker@example.com", "SR-AGRI")
    @water_maker = create_employee("Water Maker", "water.maker@example.com", "SR-WATER")
    @finance = create_employee("Finance Approver", "finance.sr@example.com", "SR-FIN")
    %w[vendor_registration_list vendor_registration_main vendor_registration].each do |menu|
      MenuPermission.create!(stakeholder_category: @stakeholder, designation: "Officer", menu_identifier: menu, can_view: true)
    end

    agri_channel = create_channel(@agriculture, @agri_maker)
    create_channel(@water, @water_maker)

    @self_registered = create_vendor("Self Registered Agri Vendor", "9811100001", user: nil, theme: @agriculture)
    pending_request(@self_registered, agri_channel)
    @other_makers_vendor = create_vendor("Water Maker Vendor", "9811100002", user: user_for(@water_maker), theme: @agriculture)
    pending_request(@other_makers_vendor, agri_channel)
  end

  test "the matching maker sees and opens a self-registered vendor" do
    sign_in user_for(@agri_maker)

    get list_vendor_registrations_url
    assert_response :success
    listed = controller.instance_variable_get(:@vendor_registrations).to_a
    assert_includes listed, @self_registered
    assert_not_includes listed, @other_makers_vendor, "vendors invited by another maker stay with that maker"

    get vendor_registration_url(@self_registered)
    assert_response :success
  end

  test "a maker of another theme does not see it" do
    sign_in user_for(@water_maker)

    get list_vendor_registrations_url
    assert_not_includes controller.instance_variable_get(:@vendor_registrations).to_a, @self_registered

    get vendor_registration_url(@self_registered)
    assert_redirected_to list_vendor_registrations_path
  end

  private

  def user_for(employee)
    User.find_by!(email: employee.email_id)
  end

  def create_employee(name, email, code)
    EmployeeMaster.create!(designation: "Officer", employee_code: code, email_id: email, name: name,
                           stakeholder_category: @stakeholder, user_type: "User")
  end

  def create_channel(theme, maker)
    channel = ApprovalChannel.new(approval_type: "Sequential", form_name: "Vendor Registration", stakeholder_category: @stakeholder, theme: theme)
    channel.approval_channel_steps.build(current_action: "Proposal Create", previous_action: "NA", step_number: 1, to_responsible_user: maker)
    channel.approval_channel_steps.build(current_action: "Finance Approval", previous_action: "Proposal Create", step_number: 2, to_responsible_user: @finance)
    channel.save!
    channel
  end

  def create_vendor(name, mobile, user:, theme:)
    vendor = VendorRegistration.new(address: "Addr", block: @block, district: @block.district, state: @block.district.state,
                                    email: "#{mobile}@example.com", firm_name: name, firm_type: "Company", mobile_no: mobile,
                                    pan_no: "ABCDE#{mobile.last(4)}F", pin_no: "123456", stakeholder_category: @stakeholder,
                                    submitted_at: Time.current, submitted_ip: "127.0.0.1", user: user, vendor_name: name)
    vendor.save!(validate: false)
    VendorRegistrationTheme.create!(vendor_registration: vendor, theme: theme)
    vendor
  end

  def pending_request(vendor, channel)
    request = ApprovalRequest.create!(approval_channel: channel, approvable: vendor, current_level: 1,
                                      form_name: "Vendor Registration", status: "pending")
    request.approval_steps.create!(current_action: "Finance Approval", employee_master: @finance, level: 1, previous_action: "NA", status: "pending")
    request
  end
end
