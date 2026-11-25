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
    @stop_dam = Product.create!(name: "Stop Dam", theme: @wrd_theme, product_code: "U50-SD")
    @earthen_dam = Product.create!(name: "Earthen Dam", theme: @wrd_theme, product_code: "U50-ED")
    @doha = Product.create!(name: "Doha Construction", theme: @wrd_theme, product_code: "U50-DH")

    @maker = employee("U50 Maker", "u50.maker@example.com", "U50-MAKER", "Procurement Maker")
    employee("U50 Director", "u50.director@example.com", "U50-DIR", "Director")
    @coo = employee("U50 COO", "u50.coo@example.com", "U50-COO", "COO")
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

  test "an item removed on the form before saving is not created" do
    sign_in user_for(@maker)
    params = quotation_params(bucket: "upto_50k", unregistered: [{ vendor_name: "Removed Row Traders", mobile_no: "9876500019" }])
    params[:quotation_proposal][:quotation_proposal_items_attributes]["1795"] =
      { _destroy: "1", item_name: "", unit_id: "", quantity: "0.0", max_rate: "", remark: "" }

    post quotation_proposals_url, params: params

    quotation = QuotationProposal.order(:id).last
    assert_redirected_to quotation_proposal_path(quotation)
    assert_equal ["Seed"], quotation.quotation_proposal_items.map(&:item_name)
  end

  test "a registered vendor's mobile is refused as unregistered and the typed rows come back" do
    registered = registered_vendor("9876500020")
    sign_in user_for(@maker)

    assert_no_difference -> { VendorRegistration.count } do
      post quotation_proposals_url, params: quotation_params(bucket: "upto_50k", unregistered: [
        { vendor_name: "New Traders", mobile_no: "9876500021" },
        { vendor_name: "Same Mobile", mobile_no: registered.mobile_no }
      ])
    end
    assert_response :unprocessable_entity
    assert_match "already belongs to the registered vendor #{registered.display_name}", response.body
    assert_match 'value="New Traders"', response.body
    assert_match 'value="9876500021"', response.body
  end

  test "the same mobile for two unregistered vendors is refused" do
    sign_in user_for(@maker)

    assert_no_difference -> { VendorRegistration.count } do
      post quotation_proposals_url, params: quotation_params(bucket: "upto_50k", unregistered: [
        { vendor_name: "First", mobile_no: "9876500022" }, { vendor_name: "Second", mobile_no: "9876500022" }
      ])
    end
    assert_match "entered for more than one unregistered vendor", response.body
  end

  test "a quotation that fails to save leaves no unregistered vendor behind" do
    sign_in user_for(@maker)
    params = quotation_params(bucket: "upto_50k", unregistered: [{ vendor_name: "Left Behind", mobile_no: "9876500023" }])
    params[:quotation_proposal][:subject] = ""

    assert_no_difference -> { VendorRegistration.count } do
      post quotation_proposals_url, params: params
    end
    assert_response :unprocessable_entity
    assert_match 'value="Left Behind"', response.body
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

    # Every "Send Registration Link" button submits the registration-link form,
    # never the committee scoring form it may sit in.
    get quotation_proposal_url(quotation)
    form = css_select("form#send-registration-link-form").first
    assert form, "registration-link form is on the page"
    assert_equal send_vendor_registration_link_quotation_proposal_path(quotation), form["action"]
    css_select("button[form]").each { |button| assert_equal "send-registration-link-form", button["form"] }

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

  test "a stop dam work gets an agreement filled from the saved details" do
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

    patch save_agreement_quotation_proposal_url(quotation), params: { agreement: agreement_details }
    assert_redirected_to agreement_quotation_proposal_path(quotation)
    get agreement_quotation_proposal_url(quotation)
    assert_match "Village- Bataikela-ll, Batouli/Sarguja, C.G.", response.body
    assert_match "complete all works within two and half (2.5) months from the commencement date, subject to the overall completion deadline of 25th Dec. 2026", response.body
    assert_match "Rs. 1,30,000/- (Rupees One Lakh Thirty Thousand only)", response.body
  end

  test "the order type chosen with the activity decides PO, Work Order or Agreement" do
    sign_in user_for(@maker)
    cases = [["purchase_order", @stop_dam, :po], ["work_order", @doha, :wo], ["agreement", @doha, :agreement],
             [nil, @earthen_dam, :agreement], [nil, @doha, :po]] # nil: WRD requests saved before the choice existed
    cases.each_with_index do |(order, activity, expected), index|
      quotation = quotation_with_selected(registered_vendor("98765001#{index}0"), theme: @wrd_theme, activity: activity, order: order)
      get purchase_order_quotation_proposal_url(quotation)
      label = "#{order.inspect} / #{activity.name}"
      case expected
      when :agreement
        assert_redirected_to agreement_quotation_proposal_path(quotation), label
      when :wo
        assert_response :success, label
        assert_match "Work Order Preview", response.body
        assert_match "WORK ORDER", response.body
        assert_match "/WO/#{quotation.id}/", response.body
        assert_no_match "PURCHASE ORDER", response.body
      else
        assert_response :success, label
        assert_match "Purchase Order Preview", response.body
        assert_match "PURCHASE ORDER", response.body
      end
    end
  end

  test "a new WRD request needs an order type; other themes keep none" do
    wrd = QuotationProposal.new(theme: @wrd_theme, activity_product: @stop_dam)
    wrd.validate
    assert_includes wrd.errors.full_messages.join, "Order type must be selected for WRD"

    other = QuotationProposal.new(theme: @theme, order_document_type: "work_order")
    other.validate
    assert_nil other.order_document_type
    assert_equal "Purchase Order", other.order_document_label
  end

  test "the agreement goes to the COO, then the signed copy, then the vendor like a PO" do
    quotation = quotation_with_selected(registered_vendor("9876500031"), theme: @wrd_theme)
    proposal_vendor = quotation.quotation_proposal_vendors.first
    sign_in user_for(@maker)

    post submit_agreement_quotation_proposal_url(quotation)
    assert_match "Fill and save Village", flash[:alert]
    assert_nil proposal_vendor.reload.agreement_approval_request

    patch save_agreement_quotation_proposal_url(quotation), params: { agreement: agreement_details }
    post send_purchase_order_quotation_proposal_url(quotation), params: { purchase_order_due_date: (Date.current + 5).iso8601 }
    assert_redirected_to agreement_quotation_proposal_path(quotation)
    assert_match "must be approved by the COO", flash[:alert]

    post submit_agreement_quotation_proposal_url(quotation)
    request = proposal_vendor.reload.agreement_approval_request
    assert_equal ["Agreement", "pending"], [request.form_name, request.status]
    assert_equal [@coo], request.approval_steps.map(&:employee_master)
    assert_not proposal_vendor.agreement_editable?
    assert_equal Date.current.iso8601, proposal_vendor.agreement_details["agreement_date"]

    # The COO sees it in My Approvals and opens it; another employee cannot.
    sign_out :user
    sign_in user_for(@coo)
    get approval_requests_url
    assert_response :success
    assert_match format("AGR-%03d", quotation.id), response.body
    assert_match agreement_quotation_proposal_path(quotation), response.body
    get agreement_quotation_proposal_url(quotation)
    assert_response :success
    assert_match "My Approvals", response.body
    sign_out :user
    sign_in user_for(@finance)
    get agreement_quotation_proposal_url(quotation)
    assert_response :redirect
    assert_no_match "CONTRACT AGREEMENT", response.body

    request.approve!(employee: @coo, remark: "OK")
    sign_out :user
    sign_in user_for(@maker)
    post send_purchase_order_quotation_proposal_url(quotation), params: { purchase_order_due_date: (Date.current + 5).iso8601 }
    assert_match "Upload the agreement signed by ASA", flash[:alert]

    post upload_signed_agreement_quotation_proposal_url(quotation),
         params: { signed_agreement: Rack::Test::UploadedFile.new(StringIO.new("text"), "text/plain", original_filename: "note.txt") }
    assert_match "PDF or an image", flash[:alert]
    post upload_signed_agreement_quotation_proposal_url(quotation),
         params: { signed_agreement: Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4 signed"), "application/pdf", original_filename: "signed.pdf") }
    assert proposal_vendor.reload.signed_agreement.attached?

    QuotationVendorSmsGateway.stub(:send_purchase_order_link, true) do
      post send_purchase_order_quotation_proposal_url(quotation), params: { purchase_order_due_date: (Date.current + 5).iso8601 }
    end
    proposal_vendor.reload
    assert_equal "sent", proposal_vendor.purchase_order_status
    assert_equal @coo, proposal_vendor.purchase_order_authorized_by
    follow_redirect!
    assert_redirected_to agreement_quotation_proposal_path(quotation), "after sending, the PO page still opens the agreement"

    # The vendor's link shows the agreement and the copy signed by ASA (a past
    # last date shows the document without the OTP step).
    proposal_vendor.update_columns(purchase_order_due_date: Date.current - 1)
    get purchase_order_vendor_qr_url(proposal_vendor.po_token)
    assert_response :success
    assert_match "CONTRACT AGREEMENT", response.body
    assert_match "signed.pdf", response.body
    proposal_vendor.update_columns(purchase_order_due_date: Date.current + 5)

    # The vendor accepts it like a purchase order; goods receive then opens.
    proposal_vendor.update!(purchase_order_status: "accepted", purchase_order_actioned_at: Time.current)
    get goods_receive_quotation_proposal_url(quotation)
    assert_response :success
  end

  test "the vendor accepts an agreement only with its signed copy; a PO is accepted as before" do
    agreement_quotation = quotation_with_selected(registered_vendor("9876500041"), theme: @wrd_theme)
    agreement_vendor = agreement_quotation.quotation_proposal_vendors.first
    agreement_vendor.update!(agreement_details: agreement_details.stringify_keys)
    ApprovalRequestBuilder.create_agreement_approval!(agreement_vendor).approve!(employee: @coo, remark: "OK")

    po_quotation = quotation_with_selected(registered_vendor("9876500042"))
    po_vendor = po_quotation.quotation_proposal_vendors.first

    [agreement_vendor, po_vendor].each do |proposal_vendor|
      proposal_vendor.ensure_po_token!
      proposal_vendor.update!(purchase_order_status: "sent", purchase_order_sent_at: Time.current, purchase_order_due_date: Date.current + 5)
    end

    QuotationVendorSmsGateway.stub(:send_vendor_otp, true) do
      vendor_verified!(agreement_vendor)
      accept = { purchase_order_decision: "accepted", purchase_order_remark: "Agreed", purchase_order_terms_accepted: "1" }

      patch purchase_order_vendor_qr_url(agreement_vendor.po_token, verified: 1), params: accept
      assert_match "Upload the agreement signed by you", flash[:alert]
      assert_equal "sent", agreement_vendor.reload.purchase_order_status

      patch purchase_order_vendor_qr_url(agreement_vendor.po_token, verified: 1),
            params: accept.merge(vendor_signed_agreement: Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4 vendor"), "application/pdf", original_filename: "vendor-signed.pdf"))
      agreement_vendor.reload
      assert_equal "accepted", agreement_vendor.purchase_order_status
      assert_equal "vendor-signed.pdf", agreement_vendor.vendor_signed_agreement.filename.to_s

      # A purchase order: no upload field, accepted without a copy, as before.
      vendor_verified!(po_vendor)
      assert_no_match "vendor_signed_agreement", response.body
      patch purchase_order_vendor_qr_url(po_vendor.po_token, verified: 1), params: accept
      assert_equal "accepted", po_vendor.reload.purchase_order_status
      assert_not po_vendor.vendor_signed_agreement.attached?
    end

    sign_in user_for(@maker)
    get agreement_quotation_proposal_url(agreement_quotation)
    assert_match "Signed by vendor:", response.body
    assert_match "vendor-signed.pdf", response.body
  end

  test "an agreement returned by the COO can be changed and sent again" do
    quotation = quotation_with_selected(registered_vendor("9876500032"), theme: @wrd_theme)
    proposal_vendor = quotation.quotation_proposal_vendors.first
    sign_in user_for(@maker)
    patch save_agreement_quotation_proposal_url(quotation), params: { agreement: agreement_details }
    post submit_agreement_quotation_proposal_url(quotation)
    proposal_vendor.reload.agreement_approval_request.return_to_employee!(employee: @coo, remark: "Fix the EMD")

    assert proposal_vendor.reload.agreement_editable?
    get agreement_quotation_proposal_url(quotation)
    assert_match "Fix the EMD", response.body
    patch save_agreement_quotation_proposal_url(quotation), params: { agreement: { emd_amount: "50000" } }
    post submit_agreement_quotation_proposal_url(quotation)
    assert_equal "pending", proposal_vendor.reload.agreement_status
    assert_equal "50000", proposal_vendor.agreement_details["emd_amount"]
    assert_equal 2, proposal_vendor.agreement_approval_requests.count
  end

  test "a WRD work of 10K-50K waits for the vendor's registration before the agreement" do
    quotation = quotation_with_selected(provisional_vendor("9876500018"), theme: @wrd_theme)
    sign_in user_for(@maker)

    get agreement_quotation_proposal_url(quotation)
    assert_redirected_to quotation_proposal_path(quotation)
    assert_match "must complete the vendor registration", flash[:alert]

    vendor = quotation.selected_vendor_registration
    vendor.update_columns(provisional: false, state_id: @state.id, district_id: @district.id, block_id: @block.id,
                          firm_name: "U50 WRD Firm", pan_no: "ABCDE0018F")
    ApprovalRequestBuilder.create_for!(vendor, form_name: "Vendor Registration").approve!(employee: @finance, remark: "OK")

    get purchase_order_quotation_proposal_url(quotation)
    assert_redirected_to agreement_quotation_proposal_path(quotation)
    get agreement_quotation_proposal_url(quotation)
    assert_response :success
    assert_match "U50 WRD Firm", response.body
  end

  test "other themes keep the purchase order" do
    quotation = quotation_with_selected(registered_vendor("9876500016"))
    sign_in user_for(@maker)

    get agreement_quotation_proposal_url(quotation)
    assert_redirected_to purchase_order_quotation_proposal_path(quotation)
  end

  private

  # Opens the vendor's PO / agreement link and verifies the OTP.
  def vendor_verified!(proposal_vendor)
    get purchase_order_vendor_qr_url(proposal_vendor.po_token)
    otp = proposal_vendor.reload.dispatch_record!.latest_active_otp.otp_code
    post verify_purchase_order_vendor_qr_otp_url(proposal_vendor.po_token), params: { otp_code: otp }
    get purchase_order_vendor_qr_url(proposal_vendor.po_token, verified: 1)
    assert_response :success
  end

  def agreement_details
    { village: "Bataikela-ll", block_district: "Batouli/Sarguja", state: "C.G.", completion_period: "two and half (2.5) months",
      completion_deadline: "2026-12-25", emd_amount: "130000" }
  end

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

  def quotation_with_selected(vendor, bucket: "upto_50k", theme: @theme, activity: (theme == @wrd_theme ? @stop_dam : nil),
                              order: (theme == @wrd_theme ? "agreement" : nil))
    quotation = QuotationProposal.new(procurement_amount_bucket: bucket, proposal_end_date: Date.current + 7.days, remark: "Remark",
                                      subject: "Selected vendor quotation subject for the test", theme: theme, activity_product: activity,
                                      order_document_type: order,
                                      user: user_for(@maker), workflow_status: "vendor_selected", vendor_rule_enforced: true)
    quotation.save!(validate: false)
    item = quotation.quotation_proposal_items.create!(item_name: "Seed", unit: @unit, quantity: 2, max_rate: 1000, remark: "Item")
    proposal_vendor = quotation.quotation_proposal_vendors.create!(vendor_registration: vendor, response_status: "responded")
    proposal_vendor.vendor_items.find_or_create_by!(quotation_proposal_item: item).update!(quoted_rate: 900, gst_percentage: 5)
    quotation.update_columns(selected_vendor_registration_id: vendor.id)
    quotation.reload
  end
end
