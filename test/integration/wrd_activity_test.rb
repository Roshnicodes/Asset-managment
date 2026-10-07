require "test_helper"

# WRD requests choose an Activity (one of the WRD theme's products) and the
# maker types the item names under it. Other themes are not affected.
class WrdActivityTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  self.fixture_table_names = []

  setup do
    @stakeholder_category = StakeholderCategory.create!(name: "WRD Stakeholder")
    @wrd = Theme.create!(name: "WRD", stakeholder_category: @stakeholder_category)
    @other_theme = Theme.create!(name: "IT Department", stakeholder_category: @stakeholder_category)
    @stop_dam = Product.create!(name: "Stop Dam", theme: @wrd, product_code: "SD01")
    @laptop = Product.create!(name: "Laptop", theme: @other_theme, product_code: "LP01")
    @unit = Unit.create!(name: "WRD Unit")
    state = State.create!(name: "WRD State", code: "WRS")
    district = District.create!(name: "WRD District", state: state)
    @block = Block.create!(name: "WRD Block", district: district)

    @maker = EmployeeMaster.create!(designation: "Procurement Maker", employee_code: "WRD-MAKER", email_id: "wrd.maker@example.com",
                                    name: "WRD Maker", stakeholder_category: @stakeholder_category, user_type: "User")
    %w[quotation_proposal_form quotation_proposal_list].each do |menu|
      MenuPermission.create!(stakeholder_category: @stakeholder_category, designation: "Procurement Maker", menu_identifier: menu, can_view: true)
    end
    [@wrd, @other_theme].each do |theme|
      channel = ApprovalChannel.new(approval_type: "Sequential", form_name: "Quotation Request", stakeholder_category: @stakeholder_category, theme: theme)
      channel.approval_channel_steps.build(current_action: "Proposal Create", previous_action: "NA", step_number: 1, to_responsible_user: @maker)
      channel.save!
    end
    @vendor = create_vendor
    @first_member = EmployeeMaster.create!(designation: "Officer", employee_code: "WRD-M1", email_id: "wrd.m1@example.com", name: "WRD Member", stakeholder_category: @stakeholder_category, user_type: "User")
    { "COO" => "WRD-COO", "Director" => "WRD-DIR", "Programme Director - Finance" => "WRD-FIN" }.each do |designation, code|
      EmployeeMaster.create!(designation: designation, employee_code: code, email_id: "#{code.downcase}@example.com", name: "WRD #{designation}", stakeholder_category: @stakeholder_category, user_type: "User")
    end
  end

  test "a new WRD request needs an Activity of the WRD theme" do
    quotation = new_quotation(theme: @wrd)
    assert_not quotation.valid?
    assert_includes quotation.errors[:activity_product], "must be selected for WRD"

    quotation.activity_product = @laptop
    assert_not quotation.valid?
    assert_includes quotation.errors[:activity_product], "must be a product of the WRD theme"

    quotation.activity_product = @stop_dam
    quotation.validate
    assert_empty quotation.errors[:activity_product]
  end

  test "other themes do not need or keep an Activity" do
    quotation = new_quotation(theme: @other_theme)
    quotation.activity_product = @stop_dam
    quotation.validate
    assert_empty quotation.errors[:activity_product]
    assert_nil quotation.activity_product_id
  end

  test "the maker creates a WRD request with an Activity and typed items" do
    sign_in User.find_by!(email: @maker.email_id)

    get new_quotation_proposal_url
    assert_response :success
    assert_select "select#quotation_proposal_theme_id option[data-wrd='true']", text: /WRD/
    assert_select "tr[data-quotation-activity-row][hidden] select[data-quotation-activity] option", text: "Stop Dam"
    assert_select "template[data-quotation-item-template] input[data-proposal-item-custom][disabled]"

    post quotation_proposals_url, params: { quotation_proposal: {
      theme_id: @wrd.id, activity_product_id: @stop_dam.id, subject: "Stop dam construction work at the village site",
      proposal_end_date: Date.current + 7.days, remark: "WRD remark", procurement_amount_bucket: "below_10k",
      vendor_registration_ids: [@vendor.id],
      committee_steps_attributes: { "0" => { level: 1, employee_master_id: @first_member.id } },
      quotation_proposal_items_attributes: {
        "0" => { item_name: "Earth excavation", unit_id: @unit.id, quantity: "10", max_rate: "500", remark: "Typed by maker" },
        "1" => { item_name: "Stone pitching", unit_id: @unit.id, quantity: "5", max_rate: "800", remark: "Typed by maker" }
      }
    } }

    errors = response.body.scan(/<li>([^<]+)<\/li>|app-form-error">([^<]+)</).flatten.compact.map(&:strip).reject(&:empty?)
    assert_response :redirect, "#{response.status} #{flash[:alert]} #{errors.join(' | ')}"
    quotation = QuotationProposal.order(:id).last
    assert_redirected_to quotation_proposal_path(quotation)
    assert_equal @stop_dam, quotation.activity_product
    assert_equal ["Earth excavation", "Stone pitching"], quotation.quotation_proposal_items.order(:id).pluck(:item_name)

    get quotation_proposal_url(quotation)
    assert_select "td", text: /Activity: Stop Dam/

    get edit_quotation_proposal_url(quotation)
    assert_select "tr[data-quotation-activity-row]:not([hidden]) option[selected]", text: "Stop Dam"
    assert_select "[data-quotation-item-list] input[data-proposal-item-custom][required][value='Earth excavation']"
  end

  private

  def new_quotation(theme:)
    quotation = QuotationProposal.new(procurement_amount_bucket: "below_10k", proposal_end_date: Date.current + 7.days, remark: "Remark",
                                      subject: "WRD activity rule quotation subject words", theme: theme, user: User.find_by!(email: @maker.email_id))
    quotation.vendor_registrations = [@vendor]
    quotation.quotation_proposal_items.build(item_name: "Earth excavation", quantity: 1, max_rate: 100, remark: "Item", unit: @unit)
    quotation
  end

  def create_vendor
    vendor = VendorRegistration.new(address: "WRD address", block: @block, district: @block.district, state: @block.district.state,
                                    business_description: "Business", company_status: "Active", contact_person_designation: "Manager",
                                    contact_person_name: "Contact", email: "wrd.vendor@example.com", firm_name: "WRD Firm", firm_type: "Company",
                                    mobile_no: "9700000199", pan_no: "ABCDE1499F", pin_no: "123490", stakeholder_category: @stakeholder_category,
                                    submitted_at: Time.current, submitted_ip: "127.0.0.1", user: User.find_by!(email: @maker.email_id), vendor_name: "WRD Vendor")
    vendor.save!(validate: false)
    vendor.themes << @wrd
    vendor
  end
end
