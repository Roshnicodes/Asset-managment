require "test_helper"

# End-to-end checks for the procurement change requests that are not covered by
# a dedicated test elsewhere (points 2, 3, 4, 5, 6, 7 and 11).
class ProcurementRequirementsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  self.fixture_table_names = []

  setup do
    @stakeholder_category = StakeholderCategory.create!(name: "Requirements Stakeholder")
    @theme = Theme.create!(name: "Requirements Theme", stakeholder_category: @stakeholder_category)
    @product = Product.create!(name: "Requirements Product", theme: @theme)
    @state = State.create!(name: "Requirements State", code: "RQS")
    @district = District.create!(name: "Requirements District", state: @state)
    @block = Block.create!(name: "Requirements Block", district: @district)
    @unit = Unit.create!(name: "Requirements Unit")

    @maker = create_employee("Req Maker", "req.maker@example.com", "RQ-MAKER", designation: "Procurement Maker")
    @approver = create_employee("Req Approver", "req.approver@example.com", "RQ-APPROVER")
    @head = create_employee("Req Thematic Head", "req.head@example.com", "RQ-HEAD")
    # Policy members used by existing (pre-Thematic Head) quotations.
    create_employee("Req COO", "req.coo@example.com", "RQ-COO", designation: "COO")
    create_employee("Req Director", "req.director@example.com", "RQ-DIR", designation: "Director")
    create_employee("Req Finance", "req.finance@example.com", "RQ-FIN", designation: "Programme Director - Finance")
    %w[quotation_proposal_form quotation_proposal_list].each do |menu|
      MenuPermission.create!(stakeholder_category: @stakeholder_category, designation: "Procurement Maker", menu_identifier: menu, can_view: true)
    end
    # A maker is someone on an approval channel's "Proposal Create" step.
    maker_channel = ApprovalChannel.new(approval_type: "Sequential", form_name: "Quotation Request", stakeholder_category: @stakeholder_category, theme: @theme)
    maker_channel.approval_channel_steps.build(current_action: "Proposal Create", previous_action: "NA", step_number: 1, to_responsible_user: @maker)
    maker_channel.save!
  end

  # --- Point 2: reuse stays valid until the financial year ends or the rate changes

  test "point 2: a received quotation is usable until 31 March and stops when the vendor rate changes" do
    source = build_quotation
    source.set_quotation_validity_from!(Time.zone.local(2026, 10, 5, 10))
    assert_equal Date.new(2027, 3, 31), source.reload.quotation_valid_until

    source.set_quotation_validity_from!(Time.zone.local(2027, 2, 1, 10))
    assert_equal Date.new(2027, 3, 31), source.reload.quotation_valid_until

    reused = build_quotation(reused_from: source)
    reused.update_columns(quotation_valid_until: Date.current + 30.days)

    source.invalidate_reused_quotations!
    assert reused.reload.quotation_valid_until < Date.current
  end

  # --- Point 3: the maker can revise the request until the committee approves

  test "point 3: the maker can edit while approval is pending, and the approval restarts" do
    quotation = build_quotation
    request = attach_approval_request(quotation, status: "pending")
    request.approval_steps.first.update!(status: "approved", actioned_at: Time.current)
    sign_in user_for(@maker)

    get edit_quotation_proposal_url(quotation)
    assert_response :success, flash[:alert]

    patch quotation_proposal_url(quotation), params: {
      quotation_proposal: {
        subject: "Revised subject for the quotation request",
        vendor_registration_ids: quotation.vendor_registration_ids
      }
    }
    errors = response.body.scan(/<li>([^<]+)<\/li>|app-form-error">([^<]+)</).flatten.compact.map(&:strip).reject(&:empty?)
    assert_redirected_to quotation_proposal_path(quotation), errors.join(" | ")
    assert_equal quotation.vendor_registration_ids, quotation.reload.vendor_registration_ids
    assert_equal "Revised subject for the quotation request", quotation.reload.subject
    assert_equal "pending", quotation.approval_request.reload.status
    assert quotation.approval_request.approval_steps.all? { |step| step.status == "pending" }
  end

  test "point 3: the maker can edit a request that is waiting for the Thematic Head" do
    quotation = build_quotation
    quotation.committee_steps.destroy_all
    quotation.update_columns(thematic_head_id: @head.id)
    quotation.request_thematic_head_decision!
    sign_in user_for(@maker)

    patch quotation_proposal_url(quotation), params: {
      quotation_proposal: {
        subject: "Revised subject while waiting for the head",
        vendor_registration_ids: quotation.vendor_registration_ids
      }
    }

    assert_redirected_to quotation_proposal_path(quotation)
    quotation.reload
    assert_equal "Revised subject while waiting for the head", quotation.subject
    assert quotation.awaiting_thematic_head_decision?
  end

  test "point 3: after committee approval the maker can no longer edit" do
    quotation = build_quotation
    attach_approval_request(quotation, status: "approved")
    sign_in user_for(@maker)

    get edit_quotation_proposal_url(quotation)
    assert_redirected_to quotation_proposal_path(quotation)
  end

  test "the maker can edit their own vendor registration draft" do
    MenuPermission.create!(stakeholder_category: @stakeholder_category, designation: "Procurement Maker", menu_identifier: "vendor_registration", can_view: true)
    registration = build_vendor_registration(mobile_no: "9811000505")
    registration.save!
    sign_in user_for(@maker)

    get edit_vendor_registration_url(registration)

    assert_response :success, flash[:alert].to_s
  end

  # --- Point 4: product type is optional

  test "point 4: a vendor registration is valid without any product type" do
    registration = build_vendor_registration(mobile_no: "9811000101")
    assert_empty registration.product_variety_ids
    assert registration.valid?, registration.errors.full_messages.to_sentence
  end

  # --- Point 5: subject must be 5 to 20 words

  test "point 5: the quotation subject must have between 5 and 20 words" do
    quotation = QuotationProposal.new(theme: @theme)

    { "Four words only here" => true, "Five words are now here" => false, (["word"] * 20).join(" ") => false, (["word"] * 21).join(" ") => true }.each do |subject, has_error|
      quotation.subject = subject
      quotation.validate
      assert_equal has_error, quotation.errors[:subject].any?, "subject with #{subject.split.size} words"
    end
  end

  # --- Point 6: open registration link and one mobile per vendor

  test "point 6: the open registration link works and a new mobile gets an OTP" do
    get "/vr"
    assert_response :success

    with_stubbed_otp do
      post "/vr", params: { mobile_no: "9811000202" }
    end

    invitation = VendorRegistrationInvitation.find_by!(mobile_no: "9811000202")
    assert_nil invitation.vendor_registration_id
    assert_redirected_to public_vendor_registration_invitation_path(invitation.token, skip_auto_otp: 1)
  end

  test "point 6: a mobile number can belong to only one vendor registration" do
    build_vendor_registration(mobile_no: "9811000303").save!

    duplicate = build_vendor_registration(mobile_no: "9811000303")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:mobile_no], "is already linked to another vendor registration"
  end

  # --- Point 7: an approved vendor updates their own details

  test "point 7: an approved vendor edits their details through the open link and approval restarts" do
    registration = build_vendor_registration(mobile_no: "9811000404")
    registration.save!
    request = ApprovalRequest.create!(approval_channel: approval_channel("Vendor Registration"), approvable: registration, form_name: "Vendor Registration", status: "approved")
    request.approval_steps.create!(employee_master: @approver, level: 1, current_action: "L1 Approval", previous_action: "NA", status: "approved", actioned_at: Time.current)

    with_stubbed_otp do
      post "/vr", params: { mobile_no: "9811000404" }
    end
    invitation = VendorRegistrationInvitation.find_by!(vendor_registration: registration)
    assert_equal "9811000404", invitation.mobile_no

    post verify_vendor_registration_invitation_otp_path(invitation.token), params: { otp_code: invitation.reload.otp_code }
    assert_redirected_to public_vendor_registration_invitation_path(invitation.token, verified: 1)

    patch register_vendor_registration_invitation_path(invitation.token), params: {
      vendor_registration: {
        address: "New updated vendor address",
        mobile_no: "9811000999",
        theme_ids: [@theme.id],
        product_ids: [@product.id]
      }
    }

    assert_response :success
    registration.reload
    assert_equal "New updated vendor address", registration.address
    assert_equal "9811000404", registration.mobile_no, "the public form must not change the registered mobile"
    assert_equal "pending", registration.approval_request.reload.status
  end

  # --- Point 11: reminders for approvals pending at a member's level

  test "point 11: the daily reminder notifies members whose approval has been pending for a day" do
    quotation = build_quotation
    request = attach_approval_request(quotation, status: "pending")
    request.update_columns(created_at: 2.days.ago)
    fresh = attach_approval_request(build_quotation, status: "pending")

    assert_difference -> { Notification.where(user: user_for(@approver)).where("title LIKE ?", "%Approval Reminder").count }, 1 do
      PendingApprovalReminderJob.perform_now
    end
    assert fresh.persisted?
  end

  private

  def user_for(employee)
    User.find_by!(email: employee.email_id)
  end

  def create_employee(name, email, employee_code, designation: "Officer")
    EmployeeMaster.create!(
      designation: designation,
      employee_code: employee_code,
      email_id: email,
      name: name,
      stakeholder_category: @stakeholder_category,
      user_type: "User"
    )
  end

  def build_quotation(reused_from: nil)
    quotation = QuotationProposal.new(
      procurement_amount_bucket: "above_10k",
      proposal_end_date: Date.current + 7.days,
      remark: "Requirements remark",
      subject: "Requirements quotation subject words",
      theme: @theme,
      user: user_for(@maker),
      reused_from_quotation_proposal: reused_from
    )
    quotation.save!(validate: false)
    quotation.quotation_proposal_items.create!(item_name: "Laptop", max_rate: 100, quantity: 2, remark: "Item remark", unit: @unit)
    vendor = build_vendor_registration(mobile_no: "97#{rand(10**8).to_s.rjust(8, "0")}")
    vendor.save!(validate: false)
    quotation.quotation_proposal_vendors.create!(vendor_registration: vendor)
    quotation.committee_steps.create!(employee_master: @approver, level: 1, status: "waiting")
    quotation
  end

  def attach_approval_request(quotation, status:)
    request = ApprovalRequest.create!(approval_channel: approval_channel("Quotation Proposal"), approvable: quotation, form_name: "Quotation Proposal", status: status, current_level: 1)
    request.approval_steps.create!(
      employee_master: @approver, level: 1, current_action: "L1 Approval", previous_action: "NA",
      status: status == "approved" ? "approved" : "pending"
    )
    quotation.committee_steps.first.update!(status: status == "approved" ? "approved" : "pending")
    request
  end

  def approval_channel(form_name)
    @approval_channels ||= {}
    @approval_channels[form_name] ||= begin
      channel = ApprovalChannel.new(approval_type: "Sequential", form_name: form_name, stakeholder_category: @stakeholder_category, theme: @theme)
      channel.approval_channel_steps.build(current_action: "L1 Approval", previous_action: "NA", step_number: 1, to_responsible_user: @approver)
      channel.save!
      channel
    end
  end

  def build_vendor_registration(mobile_no:)
    registration = VendorRegistration.new(
      address: "Requirements vendor address",
      block: @block,
      business_description: (["Business"] * 20).join(" "),
      company_status: "Active",
      contact_person_designation: "Manager",
      contact_person_name: "Contact Person",
      district: @district,
      email: "vendor.#{mobile_no}@example.com",
      firm_name: "Requirements Firm #{mobile_no}",
      firm_profile: (["Profile"] * 20).join(" "),
      firm_type: "Partnership",
      mobile_no: mobile_no,
      pan_no: "ABCDE#{mobile_no.last(4)}F",
      pin_no: "123456",
      stakeholder_category: @stakeholder_category,
      state: @state,
      submitted_at: Time.current,
      submitted_ip: "127.0.0.1",
      user: user_for(@maker),
      vendor_name: "Requirements Vendor",
      theme_ids: [@theme.id],
      product_ids: [@product.id]
    )
    bank = registration.vendor_bank_masters.build(
      bank_name: "Requirements Bank", account_type: "Savings", account_number: "1234567890",
      ifsc_code: "SBIN0001234", bank_address: "Bank address"
    )
    bank.cancelled_cheque.attach(io: StringIO.new("cheque"), filename: "cheque.pdf", content_type: "application/pdf")
    registration
  end

  def with_stubbed_otp(&block)
    QuotationVendorSmsGateway.stub(:send_vendor_registration_otp, true, &block)
  end
end
