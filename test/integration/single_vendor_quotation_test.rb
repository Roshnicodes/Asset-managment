require "test_helper"

# Above 10K a new quotation needs at least 3 vendors, or exactly one vendor
# with a note. A single-vendor request is approved by the Director alone and
# skips committee scoring; older quotations keep their previous behaviour.
class SingleVendorQuotationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  self.fixture_table_names = []

  LOGIC_NOTE = ("Only one authorised dealer supplies and installs this plant model in the region, with after-sales " \
                "service at every KBK location. Quotations from three vendors are therefore not possible. The plants " \
                "are needed as demonstration units so that farmers can see the practice, do it themselves and learn " \
                "from it before it is expanded across the programme area this year.").freeze

  setup do
    @stakeholder_category = StakeholderCategory.create!(name: "Single Vendor Stakeholder")
    @theme = Theme.create!(name: "Single Vendor Theme", stakeholder_category: @stakeholder_category)
    @state = State.create!(name: "Single Vendor State", code: "SVS")
    @district = District.create!(name: "Single Vendor District", state: @state)
    @block = Block.create!(name: "Single Vendor Block", district: @district)
    @unit = Unit.create!(name: "Single Vendor Unit")

    @maker = create_employee("SV Maker", "sv.maker@example.com", "SV-MAKER", designation: "Procurement Maker")
    @director = create_employee("SV Director", "sv.director@example.com", "SV-DIR", designation: "Director")
    @head = create_employee("SV Head", "sv.head@example.com", "SV-HEAD")
    create_employee("SV COO", "sv.coo@example.com", "SV-COO", designation: "COO")
    create_employee("SV Finance", "sv.finance@example.com", "SV-FIN", designation: "Programme Director - Finance")
    %w[quotation_proposal_form quotation_proposal_list].each do |menu|
      MenuPermission.create!(stakeholder_category: @stakeholder_category, designation: "Procurement Maker", menu_identifier: menu, can_view: true)
    end
    maker_channel = ApprovalChannel.new(approval_type: "Sequential", form_name: "Quotation Request", stakeholder_category: @stakeholder_category, theme: @theme)
    maker_channel.approval_channel_steps.build(current_action: "Proposal Create", previous_action: "NA", step_number: 1, to_responsible_user: @maker)
    maker_channel.save!

    @vendors = Array.new(3) { |index| create_vendor(index) }
  end

  test "above 10K: two vendors are not allowed" do
    quotation = new_quotation(vendors: @vendors.first(2))

    assert_not quotation.valid?
    assert_includes quotation.errors[:base], "Select at least 3 vendors, or a single vendor with a Logic Note."
  end

  test "above 10K: one vendor needs a note" do
    quotation = new_quotation(vendors: @vendors.first(1))
    quotation.validate
    assert_includes quotation.errors[:single_vendor_justification], "is required when only one vendor is selected"

    quotation.single_vendor_justification = "Only authorised dealer in the district"
    quotation.validate
    assert_includes quotation.errors[:single_vendor_justification], "must be at least 50 words"

    quotation.single_vendor_justification = "#{LOGIC_NOTE} Item: [item]"
    quotation.validate
    assert_includes quotation.errors[:single_vendor_justification], "still has [ ] placeholders from the format; replace them with the real details"

    quotation.single_vendor_justification = LOGIC_NOTE
    quotation.validate
    assert_empty quotation.errors[:single_vendor_justification]
    assert_empty quotation.errors[:base].grep(/at least 3 vendors/)
  end

  test "above 10K: three vendors follow the normal committee" do
    quotation = new_quotation(vendors: @vendors)
    quotation.validate

    assert_empty quotation.errors[:base].grep(/at least 3 vendors/)
    assert_not quotation.single_vendor?
  end

  test "below 10K and older quotations are not affected" do
    below = new_quotation(vendors: @vendors.first(1), bucket: "below_10k")
    below.validate
    assert_empty below.errors[:single_vendor_justification]
    assert_not below.single_vendor?

    older = new_quotation(vendors: @vendors.first(2))
    older.save!(validate: false)
    older.update_columns(vendor_rule_enforced: false)
    older.reload.validate
    assert_empty older.errors[:base].grep(/at least 3 vendors/)
    assert_not older.single_vendor?
  end

  test "a single-vendor request gets a Director-only committee and no Thematic Head" do
    quotation = new_quotation(vendors: @vendors.first(1), note: LOGIC_NOTE)
    quotation.thematic_head = @head

    assert quotation.apply_configured_committee!
    quotation.save!

    quotation.reload
    assert quotation.single_vendor?
    assert_nil quotation.thematic_head_id
    assert_equal [@director.id], quotation.committee_steps.map(&:employee_master_id)
  end

  test "end to end: maker creates a single-vendor request, Director approves, vendor is selected without scoring" do
    sign_in user_for(@maker)

    post quotation_proposals_url, params: {
      quotation_proposal: {
        theme_id: @theme.id,
        subject: "Single vendor laptop purchase for the office",
        proposal_end_date: Date.current + 7.days,
        remark: "Single vendor remark",
        procurement_amount_bucket: "above_10k",
        single_vendor_justification: LOGIC_NOTE,
        vendor_registration_ids: [@vendors.first.id],
        quotation_proposal_items_attributes: { "0" => { item_name: "Laptop", unit_id: @unit.id, quantity: "2", max_rate: "50000", remark: "Item remark" } }
      }
    }

    errors = response.body.scan(/<li>([^<]+)<\/li>|app-form-error">([^<]+)</).flatten.compact.map(&:strip).reject(&:empty?)
    assert_response :redirect, "#{response.status} #{flash[:alert]} #{errors.join(' | ')}"
    quotation = QuotationProposal.order(:id).last
    assert_redirected_to quotation_proposal_path(quotation)
    assert quotation.single_vendor?
    assert_equal [@director.id], quotation.committee_steps.map(&:employee_master_id)

    get quotation_proposal_url(quotation)
    assert_select "form button", text: "Send to Director"

    post send_for_approval_quotation_proposal_url(quotation)
    request = quotation.reload.approval_request
    assert_equal [@director.id], request.approval_steps.map(&:employee_master_id)

    request.approve!(employee: @director, remark: "OK")
    assert quotation.reload.committee_completed?

    proposal_vendor = quotation.quotation_proposal_vendors.first
    proposal_vendor.vendor_items.each { |item| item.update!(quoted_rate: 48_000, gst_percentage: 18) }
    proposal_vendor.update!(response_status: "responded", responded_at: Time.current)

    get quotation_proposal_url(quotation)
    assert_response :success
    assert_equal @vendors.first.id, quotation.reload.selected_vendor_registration_id
    assert_select "h3", text: /Committee Comparison/, count: 0
  end

  test "admin can route single-vendor requests to the COO instead of the Director" do
    coo = EmployeeMaster.find_by!(employee_code: "SV-COO")
    assert_equal "Director", AppSetting.single_vendor_approver_designation

    AppSetting.set(AppSetting::SINGLE_VENDOR_APPROVER, "COO")
    quotation = new_quotation(vendors: @vendors.first(1), note: LOGIC_NOTE)
    assert quotation.apply_configured_committee!
    quotation.save!

    assert_equal [coo.id], quotation.reload.committee_steps.map(&:employee_master_id)
    assert_equal "COO", quotation.single_vendor_approver_label
  end

  test "only an admin can open and change Procurement Settings" do
    sign_in user_for(@maker)
    get procurement_settings_url
    assert_redirected_to root_path

    admin = EmployeeMaster.create!(designation: "Admin", employee_code: "SV-ADMIN", email_id: "sv.admin@example.com",
                                   name: "SV Admin", stakeholder_category: @stakeholder_category, user_type: "Admin")
    admin_user = User.find_by!(email: admin.email_id)
    admin_user.update_columns(role: "admin")
    sign_in admin_user

    get procurement_settings_url
    assert_response :success
    assert_select "input[name='single_vendor_approver'][value='Director'][checked]"

    patch procurement_settings_url, params: { single_vendor_approver: "COO" }
    assert_redirected_to procurement_settings_path
    assert_equal "COO", AppSetting.single_vendor_approver_designation

    patch procurement_settings_url, params: { single_vendor_approver: "Someone" }
    assert_equal "COO", AppSetting.single_vendor_approver_designation
  end

  test "the form offers the Logic Note format behind an i button" do
    sign_in user_for(@maker)

    get new_quotation_proposal_url

    assert_response :success
    assert_select "button[data-logic-note-toggle]", text: "i"
    assert_select "[data-logic-note-help] .logic-note-help__sample", text: /Reason for a Single Vendor/
    assert_select "template[data-logic-note-template]"
    assert_select "textarea[name='quotation_proposal[single_vendor_justification]'][data-min-words='50']"
  end

  private

  def user_for(employee)
    User.find_by!(email: employee.email_id)
  end

  def create_employee(name, email, code, designation: "Officer")
    EmployeeMaster.create!(designation: designation, employee_code: code, email_id: email, name: name,
                           stakeholder_category: @stakeholder_category, user_type: "User")
  end

  def create_vendor(index)
    vendor = VendorRegistration.new(
      address: "Single vendor address", block: @block, business_description: "Business", company_status: "Active",
      contact_person_designation: "Manager", contact_person_name: "Contact", district: @district,
      email: "sv.vendor#{index}@example.com", firm_name: "SV Firm #{index}", firm_type: "Company",
      mobile_no: "970000009#{index}", pan_no: "ABCDE149#{index}F", pin_no: "123490",
      stakeholder_category: @stakeholder_category, state: @state, submitted_at: Time.current,
      submitted_ip: "127.0.0.1", user: user_for(@maker), vendor_name: "SV Vendor #{index}"
    )
    vendor.save!(validate: false)
    vendor.create_approval_request!(form_name: "Vendor Registration", status: "approved",
                                    approval_channel: vendor_channel) if vendor.approval_request.blank?
    vendor
  end

  def vendor_channel
    @vendor_channel ||= begin
      channel = ApprovalChannel.new(approval_type: "Sequential", form_name: "Vendor Registration", stakeholder_category: @stakeholder_category, theme: @theme)
      channel.approval_channel_steps.build(current_action: "L1 Approval", previous_action: "NA", step_number: 1, to_responsible_user: @head)
      channel.save!
      channel
    end
  end

  def new_quotation(vendors:, bucket: "above_10k", note: nil)
    quotation = QuotationProposal.new(
      procurement_amount_bucket: bucket, proposal_end_date: Date.current + 7.days, remark: "Remark",
      subject: "Single vendor rule quotation subject", theme: @theme, user: user_for(@maker),
      single_vendor_justification: note
    )
    quotation.vendor_registrations = vendors
    quotation.quotation_proposal_items.build(item_name: "Laptop", quantity: 2, max_rate: 50_000, remark: "Item", unit: @unit)
    quotation.vendor_rule_enforced = true
    quotation
  end
end
