require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  tests ApplicationHelper
  self.fixture_table_names = []
  self.fixture_sets = {}
  self.fixture_class_names = {}

  def current_employee_master
    @current_employee_master
  end

  test "navbar logo uses attached stakeholder logo for current employee" do
    stakeholder = StakeholderCategory.create!(name: "PGPL")
    stakeholder.logo_file.attach(
      io: StringIO.new("pgpl-logo"),
      filename: "pgpl.jpeg",
      content_type: "image/jpeg"
    )

    @current_employee_master = EmployeeMaster.new(
      name: "User 2",
      email_id: "user2@example.com",
      user_type: "User",
      stakeholder_category: stakeholder
    )

    assert_match %r{\A/rails/active_storage/blobs/redirect/}, navbar_logo_source
    assert_match %r{/pgpl\.jpeg\z}, navbar_logo_source
    assert_equal "PGPL Logo", navbar_logo_alt
  end

  test "catalog item labels include product and product type codes" do
    theme = Theme.create!(name: "Solar")
    product_code = "PRD-#{SecureRandom.hex(3).upcase}"
    product_type_code = "TYPE-#{SecureRandom.hex(3).upcase}"
    product = Product.create!(name: "Pump", product_code: product_code, theme: theme)
    product_type = ProductVariety.create!(name: "Heavy Duty", product_type_code: product_type_code, product: product)

    assert_equal "#{product_code} | Pump", catalog_item_option_label(product)
    assert_equal "#{product_type_code} | Heavy Duty (Pump)", catalog_item_option_label(product_type)
  end

  test "quotation item display name resolves matching product or product type codes" do
    theme = Theme.create!(name: "Irrigation")
    product_code = "PRD-#{SecureRandom.hex(3).upcase}"
    product_type_code = "TYPE-#{SecureRandom.hex(3).upcase}"
    product = Product.create!(name: "Motor", product_code: product_code, theme: theme)
    ProductVariety.create!(name: "Premium", product_type_code: product_type_code, product: product)

    assert_equal "#{product_code} | Motor", quotation_item_display_name("Motor")
    assert_equal "#{product_type_code} | Premium (Motor)", quotation_item_display_name("Premium")
    assert_equal product_type_code, quotation_item_product_type_code("Premium")
    assert_nil quotation_item_product_type_code("Motor")
    assert_equal "Custom Item", quotation_item_display_name("Custom Item")
    assert_nil quotation_item_product_type_code("Custom Item")
  end
end
