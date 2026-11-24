require "test_helper"

# A vendor registration sent for approval by a maker has one approval step:
# the Senior Manager Finance, even when its approval channel has more steps.
class VendorRegistrationSingleApprovalTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @stakeholder = StakeholderCategory.create!(name: "Single Approval Stakeholder")
    @theme = Theme.create!(name: "Single Approval Theme", stakeholder_category: @stakeholder)
    @maker = employee("Single Maker", "single.maker@example.com", "SA-MAKER", "Officer")
    @l1 = employee("Single L1", "single.l1@example.com", "SA-L1", "Manager")
    @finance = employee("Single Finance", "single.finance@example.com", "SA-FIN", "Senior Manager Finance")

    channel = ApprovalChannel.new(approval_type: "Sequential", form_name: "Vendor Registration", stakeholder_category: @stakeholder, theme: @theme)
    channel.approval_channel_steps.build(current_action: "Proposal Create", previous_action: "NA", step_number: 1, to_responsible_user: @maker)
    channel.approval_channel_steps.build(current_action: "L1 Approval", previous_action: "Proposal Create", step_number: 2, to_responsible_user: @l1)
    channel.save!

    state = State.create!(name: "Single State", code: "SAS")
    district = District.create!(name: "Single District", state: state)
    block = Block.create!(name: "Single Block", district: district)
    @vendor = VendorRegistration.new(address: "Addr", block: block, district: district, state: state, email: "v@example.com",
                                     firm_name: "Single Vendor", firm_type: "Company", mobile_no: "9811300001", pan_no: "ABCDE3001F",
                                     pin_no: "123456", stakeholder_category: @stakeholder, submitted_at: Time.current,
                                     submitted_ip: "127.0.0.1", user: User.find_by!(email: @maker.email_id), vendor_name: "Single Vendor")
    @vendor.save!(validate: false)
    VendorRegistrationTheme.create!(vendor_registration: @vendor, theme: @theme)
  end

  test "the only approval step is the Senior Manager Finance" do
    request = ApprovalRequestBuilder.create_for!(@vendor, form_name: "Vendor Registration")

    assert_equal "pending", request.status
    steps = request.approval_steps.order(:level).to_a
    assert_equal 1, steps.size
    assert_equal @finance, steps.first.employee_master
    assert_equal "pending", steps.first.status
  end

  test "finance approval completes the registration" do
    request = ApprovalRequestBuilder.create_for!(@vendor, form_name: "Vendor Registration")
    request.approve!(employee: @finance, remark: "OK")
    assert_equal "approved", request.reload.status
  end

  private

  def employee(name, email, code, designation)
    EmployeeMaster.create!(designation: designation, employee_code: code, email_id: email, name: name,
                           stakeholder_category: @stakeholder, user_type: "User")
  end
end
