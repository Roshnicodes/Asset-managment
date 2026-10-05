require "test_helper"

# A received quotation can be reused with revised quantities to create a
# purchase order draft directly, without a new quotation request.
class QuotationReuseTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  self.fixture_table_names = []

  setup do
    @stakeholder_category = StakeholderCategory.create!(name: "Reuse Stakeholder")
    @theme = Theme.create!(name: "Reuse Theme", stakeholder_category: @stakeholder_category)
    @state = State.create!(name: "Reuse State", code: "RUS")
    @district = District.create!(name: "Reuse District", state: @state)
    @block = Block.create!(name: "Reuse Block", district: @district)
    @unit = Unit.create!(name: "Reuse Unit")

    maker = EmployeeMaster.create!(
      designation: "Officer",
      employee_code: "RU-MAKER",
      email_id: "reuse.maker@example.com",
      name: "Reuse Maker",
      stakeholder_category: @stakeholder_category,
      user_type: "Admin"
    )
    @maker_user = User.find_by!(email: maker.email_id)

    @source = QuotationProposal.new(
      committee_approval_required: false,
      procurement_amount_bucket: "above_10k",
      proposal_end_date: Date.current + 7.days,
      remark: "Reuse source remark",
      subject: "Reuse source quotation subject words",
      theme: @theme,
      user: @maker_user,
      quotation_valid_until: Date.current + 30.days
    )
    @source.save!(validate: false)
    @item = @source.quotation_proposal_items.create!(item_name: "Laptop", max_rate: 50_000, quantity: 10, remark: "Item remark", unit: @unit)

    @vendor_registration = VendorRegistration.new(
      address: "Reuse address",
      block: @block,
      business_description: "Reuse business description",
      company_status: "Active",
      contact_person_designation: "Manager",
      contact_person_name: "Contact Person",
      district: @district,
      email: "reuse.vendor@example.com",
      firm_name: "Reuse Firm",
      firm_type: "Company",
      mobile_no: "9700000071",
      pan_no: "ABCDE1371F",
      pin_no: "123482",
      stakeholder_category: @stakeholder_category,
      state: @state,
      submitted_at: Time.current,
      submitted_ip: "127.0.0.1",
      user: @maker_user,
      vendor_name: "Reuse Vendor"
    )
    @vendor_registration.save!(validate: false)

    proposal_vendor = @source.quotation_proposal_vendors.create!(vendor_registration: @vendor_registration, response_status: "responded", responded_at: Time.current)
    proposal_vendor.vendor_items.find_or_create_by!(quotation_proposal_item: @item).update!(quoted_rate: 48_000, gst_percentage: 18)
    @source.update_columns(selected_vendor_registration_id: @vendor_registration.id)
  end

  test "reusing a quotation with a revised quantity creates a purchase order draft" do
    sign_in @maker_user

    assert_difference -> { QuotationProposal.count }, 1 do
      post reuse_quotation_proposal_url(@source), params: { quantities: { @item.id.to_s => "4" } }
    end

    reused = QuotationProposal.order(:id).last
    assert_redirected_to purchase_order_quotation_proposal_path(reused)
    assert_equal @source.id, reused.reused_from_quotation_proposal_id
    assert_equal @vendor_registration.id, reused.selected_vendor_registration_id
    assert_equal [4], reused.quotation_proposal_items.map { |item| item.quantity.to_i }

    reused_vendor = reused.quotation_proposal_vendors.first
    assert_equal [48_000], reused_vendor.vendor_items.map { |item| item.quoted_rate.to_i }
  end
end
