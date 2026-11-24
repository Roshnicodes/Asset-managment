require "test_helper"

# Up to 50K a quotation may include vendors without a registration (name and
# mobile only). The selected one must register (Finance approval) before the
# purchase order. WRD works get an agreement instead of a purchase order.
class Upto50kUnregisteredVendorTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  self.fixture_table_names = []

  LOGIC_NOTE = ("Only one authorised dealer supplies and installs this plant model in the region, with after-sales " \
                "service at every KBK location. Quotations from three vendors are therefore not possible. The plants " \
                "are needed as demonstration units so that farmers can see the practice, do it themselves and learn " \
                "from it before it is expanded across the programme area this year.").freeze

  setup do
    @stakeholder = StakeholderCategory.create!(name: "Upto50 Stakeholder")
    @theme = Theme.create!(name: "Upto50 Theme", stakeholder_category: @stakeholder)
    @wrd_theme = Theme.create!(name: "WRD Upto50", stakeholder_category: @stakeholder)
    @state = State.create!(name: "Upto50 State", code: "U50")
    @district = District.create!(name: "Upto50 District", state: @state)
    @block = Block.create!(name: "Upto50 Block", district: @district)
    @unit = Unit.create!(name: "Upto50 Unit")

    @maker = employee("U50 Maker", "u50.maker@example.com", "U50-MAKER", "Procurement Maker")
    employee("U50 Director", "u50.director@example.com", "U50-DIR", "Director")
    employee("U50 COO", "u50.coo@example.com", "U50-COO", "COO")
    @finance = employee("U50 Finance", "u50.finance@example.com", "U50-FIN", "Senior Manager Finance")
    %w[quotation_proposal_form quotation_proposal_list quotation_proposal_main vendor_registration].each do |menu|
      MenuPermission.create!(stakeholder_category: @stakeholder, designation: "Procurement Maker", menu_identifier: menu, can_view: true)
    end
    channel = ApprovalChannel.new(approval_type: "Sequential", form_name: "Quotation Request", stakeholder_category: @stakeholder, theme: @theme)
    channel.approval_channel_steps.build(current_action: "Proposal Create", previous_action: "NA", step_number: 1, to_responsible_user: @maker)
    channel.save!
    vendor_channel = ApprovalChannel.new(approval_type: "Sequential", form_name: "Vendor Registration", stakeholder_category: @stakeholder, theme: @theme)
    vendor_channel.approval_channel_steps.build(current_action: "Proposal Create", previous_action: "NA", step_number: 1, to_responsible_user: @maker)
    vendor_channel.save!
  end

  test "value options and the up-to-50K rule" do
    quotation = QuotationProposal.new
    { "below_10k" => ["Below 10K", false, false], "upto_50k" => ["10K - 50K", true, true],
      "above_50k" => ["Above 50K", true, false], "above_10k" => ["Above 10K", true, false] }.each do |bucket, (label, above, optional)|
      quotation.procurement_amount_bucket = bucket
      assert_equal label, quotation.procurement_amount_bucket_label
      assert_equal above, quotation.above_10k?, bucket
      assert_equal optional, quotation.vendor_registration_optional?, bucket
    end
  end

  test "a maker adds an unregistered vendor to a 10K-50K quotation" do
    sign_in user_for(@maker)

    assert_difference -> { VendorRegistration.where(provisional: true).count }, 1 do
      post quotation_proposals_url, params: quotation_params(bucket: "upto_50k", unregistered: [{ vendor_name: "Ramu Traders", firm_name: "", mobile_no: "9876500011" }])
    end

    quotation = QuotationProposal.order(:id).last
    assert_redirected_to quotation_proposal_path(quotation)
    vendor = quotation.vendor_registrations.first
    assert vendor.provisional?
    assert_equal ["Ramu Traders", "9876500011"], [vendor.vendor_name, vendor.mobile_no]

    get vendor_registrations_url
    assert_not_includes controller.instance_variable_get(:@vendor_registrations).to_a, vendor, "not listed as a registration"
  end

  test "the quotation scan uploaded with an unregistered vendor is kept with its quotation" do
    sign_in user_for(@maker)
    scan = Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4 scan"), "application/pdf", original_filename: "ramu-quote.pdf")

    post quotation_proposals_url, params: quotation_params(bucket: "upto_50k", unregistered: [{ vendor_name: "Ramu Scan Traders", mobile_no: "9876500017", scan: scan }])

    quotation = QuotationProposal.order(:id).last
    assert_redirected_to quotation_proposal_path(quotation)
    proposal_vendor = quotation.quotation_proposal_vendors.first
    assert_equal ["ramu-quote.pdf"], proposal_vendor.vendor_documents.map { |document| document.filename.to_s }

    get quotation_proposal_url(quotation)
    assert_match "ramu-quote.pdf", response.body
  end

  test "above 50K an unregistered vendor is refused and nothing is created" do
    sign_in user_for(@maker)

    assert_no_difference -> { VendorRegistration.count } do
      post quotation_proposals_url, params: quotation_params(bucket: "above_50k", unregistered: [{ vendor_name: "Ramu Traders", mobile_no: "9876500012" }])
    end
    assert_response :unprocessable_entity
    assert_match "only be added for quotations of 10K - 50K", response.body
  end

  test "the purchase order waits for the selected vendor's registration" do
    quotation = quotation_with_selected(provisional_vendor("9876500013"))
    sign_in user_for(@maker)

    get purchase_order_quotation_proposal_url(quotation)
    assert_redirected_to quotation_proposal_path(quotation)
    assert_match "must complete the vendor registration", flash[:alert]

    QuotationVendorSmsGateway.stub(:send_vendor_registration_link, true) do
      assert_difference -> { VendorRegistrationInvitation.count }, 1 do
        post send_vendor_registration_link_quotation_proposal_url(quotation)
      end
    end
    invitation = VendorRegistrationInvitation.order(:id).last
    assert_equal quotation.selected_vendor_registration, invitation.vendor_registration
    assert_match "Registration link sent", flash[:notice]

    # Vendor completes the registration; Finance approves it.
    vendor = quotation.selected_vendor_registration
    vendor.update_columns(provisional: false, state_id: @state.id, district_id: @district.id, block_id: @block.id)
    ApprovalRequestBuilder.create_for!(vendor, form_name: "Vendor Registration").approve!(employee: @finance, remark: "OK")

    get purchase_order_quotation_proposal_url(quotation)
    assert_response :success
  end

  test "above 50K the purchase order is not held back" do
    quotation = quotation_with_selected(provisional_vendor("9876500014"), bucket: "above_50k")
    assert_not quotation.selected_vendor_registration_pending?
  end

  test "a WRD work gets an agreement instead of a purchase order" do
    quotation = quotation_with_selected(registered_vendor("9876500015"), theme: @wrd_theme)
    sign_in user_for(@maker)

    get purchase_order_quotation_proposal_url(quotation)
    assert_redirected_to agreement_quotation_proposal_path(quotation)

    get agreement_quotation_proposal_url(quotation)
    assert_response :success
    assert_match "CONTRACT AGREEMENT", response.body
    assert_match "U50 Firm 9876500015", response.body
    assert_match "ACTION FOR SOCIAL ADVANCEMENT (ASA)</strong>, a non-profit development organization", response.body
    assert_match "Rs. 1,890/- (Rupees One Thousand Eight Hundred Ninety only inclusive all taxes)", response.body

    get agreement_quotation_proposal_url(quotation, village: "Bataikela-ll", block_district: "Batouli/Sarguja", state: "C.G.",
                                                    completion_period: "two and half (2.5) months", completion_deadline: "2026-12-25", emd_amount: "130000")
    assert_match "Village- Bataikela-ll, Batouli/Sarguja, C.G.", response.body
    assert_match "complete all works within two and half (2.5) months from the commencement date, subject to the overall completion deadline of 25th Dec. 2026", response.body
    assert_match "Rs. 1,30,000/- (Rupees One Lakh Thirty Thousand only)", response.body
  end

  test "other themes keep the purchase order" do
    quotation = quotation_with_selected(registered_vendor("9876500016"))
    sign_in user_for(@maker)

    get agreement_quotation_proposal_url(quotation)
    assert_redirected_to purchase_order_quotation_proposal_path(quotation)
  end

  private

  def employee(name, email, code, designation)
    EmployeeMaster.create!(designation: designation, employee_code: code, email_id: email, name: name,
                           stakeholder_category: @stakeholder, user_type: "User")
  end

  def user_for(employee)
    User.find_by!(email: employee.email_id)
  end

  def quotation_params(bucket:, unregistered:)
    {
      quotation_proposal: {
        theme_id: @theme.id, subject: "Up to fifty thousand seed purchase for the field",
        proposal_end_date: Date.current + 7.days, remark: "Remark", procurement_amount_bucket: bucket,
        single_vendor_justification: LOGIC_NOTE, unregistered_vendors: unregistered,
        quotation_proposal_items_attributes: { "0" => { item_name: "Seed", unit_id: @unit.id, quantity: "2", max_rate: "1000", remark: "Item" } }
      }
    }
  end

  def provisional_vendor(mobile)
    VendorRegistration.create_provisional!(vendor_name: "U50 Provisional #{mobile}", firm_name: "", mobile_no: mobile,
                                           user: user_for(@maker), theme: @theme)
  end

  def registered_vendor(mobile)
    vendor = VendorRegistration.new(address: "Addr", block: @block, district: @district, state: @state, email: "#{mobile}@example.com",
                                    firm_name: "U50 Firm #{mobile}", firm_type: "Company", mobile_no: mobile, pan_no: "ABCDE#{mobile.last(4)}F",
                                    pin_no: "123456", stakeholder_category: @stakeholder, submitted_at: Time.current, submitted_ip: "127.0.0.1",
                                    user: user_for(@maker), vendor_name: "U50 Registered #{mobile}")
    vendor.save!(validate: false)
    ApprovalRequestBuilder.create_for!(vendor, form_name: "Vendor Registration").approve!(employee: @finance, remark: "OK")
    vendor
  end

  def quotation_with_selected(vendor, bucket: "upto_50k", theme: @theme)
    quotation = QuotationProposal.new(procurement_amount_bucket: bucket, proposal_end_date: Date.current + 7.days, remark: "Remark",
                                      subject: "Selected vendor quotation subject for the test", theme: theme,
                                      user: user_for(@maker), workflow_status: "vendor_selected")
    quotation.save!(validate: false)
    item = quotation.quotation_proposal_items.create!(item_name: "Seed", unit: @unit, quantity: 2, max_rate: 1000, remark: "Item")
    proposal_vendor = quotation.quotation_proposal_vendors.create!(vendor_registration: vendor, response_status: "responded")
    proposal_vendor.vendor_items.find_or_create_by!(quotation_proposal_item: item).update!(quoted_rate: 900, gst_percentage: 5)
    quotation.update_columns(selected_vendor_registration_id: vendor.id)
    quotation.reload
  end
end
