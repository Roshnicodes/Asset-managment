require "test_helper"

# Invoice upload SMS use the DLT-approved /p?t=TOKEN link. The /p page must
# send an invoice token on to the vendor's invoice upload page.
class InvoiceSmsLinkTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    @stakeholder_category = StakeholderCategory.create!(name: "Invoice Link Stakeholder")
    @theme = Theme.create!(name: "Invoice Link Theme", stakeholder_category: @stakeholder_category)
    @state = State.create!(name: "Invoice Link State", code: "ILS")
    @district = District.create!(name: "Invoice Link District", state: @state)
    @block = Block.create!(name: "Invoice Link Block", district: @district)

    maker = EmployeeMaster.create!(
      designation: "Officer",
      employee_code: "IL-MAKER",
      email_id: "invoice.link.maker@example.com",
      name: "Invoice Link Maker",
      stakeholder_category: @stakeholder_category,
      user_type: "User"
    )
    maker_user = User.find_by!(email: maker.email_id)

    quotation_proposal = QuotationProposal.new(
      procurement_amount_bucket: "above_10k",
      proposal_end_date: Date.current + 7.days,
      remark: "Invoice link remark",
      subject: "Invoice link quotation subject words",
      theme: @theme,
      user: maker_user
    )
    quotation_proposal.save!(validate: false)

    vendor_registration = VendorRegistration.new(
      address: "Invoice link address",
      block: @block,
      business_description: "Invoice link business description",
      company_status: "Active",
      contact_person_designation: "Manager",
      contact_person_name: "Contact Person",
      district: @district,
      email: "invoice.link.vendor@example.com",
      firm_name: "Invoice Link Firm",
      firm_type: "Company",
      mobile_no: "9700000061",
      pan_no: "ABCDE1361F",
      pin_no: "123481",
      stakeholder_category: @stakeholder_category,
      state: @state,
      submitted_at: Time.current,
      submitted_ip: "127.0.0.1",
      user: maker_user,
      vendor_name: "Invoice Link Vendor"
    )
    vendor_registration.save!(validate: false)

    proposal_vendor = quotation_proposal.quotation_proposal_vendors.create!(vendor_registration: vendor_registration)
    @invoice_request = proposal_vendor.invoice_requests.create!(requested_at: Time.current, status: "pending_invoice", item_snapshot: [])
    @invoice_request.ensure_request_token!
  end

  test "the invoice SMS link uses the DLT-approved /p?t= format" do
    link = QuotationVendorSmsGateway.goods_receive_invoice_sms_link_for_config(@invoice_request.request_token, config: { profile: :asa })

    assert_match %r{/p\?t=#{@invoice_request.request_token}\z}, link
  end

  test "opening /p?t= with an invoice token leads to the invoice upload page" do
    get "/p", params: { t: @invoice_request.request_token }

    assert_redirected_to goods_receive_vendor_qr_path(@invoice_request.request_token)
  end
end
