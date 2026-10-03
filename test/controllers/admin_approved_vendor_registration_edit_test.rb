require "test_helper"

# Once a vendor registration is approved the maker can no longer change it, but
# an admin can still correct it without disturbing the approval.
class AdminApprovedVendorRegistrationEditTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  self.fixture_table_names = []

  setup do
    @stakeholder_category = StakeholderCategory.create!(name: "Vendor Edit Stakeholder")
    @theme = Theme.create!(name: "Vendor Edit Theme", stakeholder_category: @stakeholder_category)
    @state = State.create!(name: "Vendor Edit State", code: "VES")
    @district = District.create!(name: "Vendor Edit District", state: @state)
    @block = Block.create!(name: "Vendor Edit Block", district: @district)

    @maker = create_employee("Vendor Edit Maker", "vendor.edit.maker@example.com", "VE-MAKER", "User")
    @admin = create_employee("Vendor Edit Admin", "vendor.edit.admin@example.com", "VE-ADMIN", "Admin")
    @approver = create_employee("Vendor Edit Approver", "vendor.edit.approver@example.com", "VE-APPROVER", "User")

    @vendor_registration = build_vendor_registration
    @approval_request = approve!(@vendor_registration)
  end

  test "admin can open the edit form of an approved vendor registration" do
    sign_in User.find_by!(email: @admin.email_id)

    get vendor_registration_url(@vendor_registration)
    assert_select "a[href=?]", edit_vendor_registration_path(@vendor_registration)

    get edit_vendor_registration_url(@vendor_registration)
    assert_response :success
  end

  test "maker cannot edit an approved vendor registration" do
    sign_in User.find_by!(email: @maker.email_id)

    get edit_vendor_registration_url(@vendor_registration)
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

  def build_vendor_registration
    vendor_registration = VendorRegistration.new(
      address: "Vendor edit address",
      block: @block,
      business_description: "Vendor edit business description",
      company_status: "Active",
      contact_person_designation: "Manager",
      contact_person_name: "Contact Person",
      district: @district,
      email: "vendor.edit@example.com",
      firm_name: "Vendor Edit Firm",
      firm_type: "Company",
      mobile_no: "9811122277",
      pan_no: "ABCDE1277F",
      pin_no: "123477",
      stakeholder_category: @stakeholder_category,
      state: @state,
      submitted_at: Time.current,
      submitted_ip: "127.0.0.1",
      user: User.find_by!(email: @maker.email_id),
      vendor_name: "Vendor Edit Vendor"
    )
    vendor_registration.save!(validate: false)
    vendor_registration
  end

  def approve!(vendor_registration)
    channel = ApprovalChannel.new(approval_type: "Sequential", form_name: "Vendor Registration", stakeholder_category: @stakeholder_category, theme: @theme)
    channel.approval_channel_steps.build(current_action: "L1 Approval", previous_action: "NA", step_number: 1, to_responsible_user: @approver)
    channel.save!

    request = ApprovalRequest.create!(approval_channel: channel, approvable: vendor_registration, form_name: "Vendor Registration", status: "approved")
    request.approval_steps.create!(current_action: "L1 Approval", employee_master: @approver, level: 1, previous_action: "NA", status: "approved")
    request
  end
end
