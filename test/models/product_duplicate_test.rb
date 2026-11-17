require "test_helper"

# A product is entered once per theme and a product type once per product;
# case and extra spaces do not make a new one.
class ProductDuplicateTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    stakeholder = StakeholderCategory.create!(name: "Dup Stakeholder")
    @agri = Theme.create!(name: "Dup Agriculture", stakeholder_category: stakeholder)
    @water = Theme.create!(name: "Dup Water", stakeholder_category: stakeholder)
    @wheat = Product.create!(name: "Wheat Seed", product_code: "WS-01", theme: @agri)
  end

  test "the same product name in the same theme is refused, whatever the case or spaces" do
    duplicate = Product.new(name: "  wheat   SEED ", theme: @agri)
    assert_not duplicate.valid?
    assert_match "already exists in this theme", duplicate.errors[:name].join
  end

  test "the same name in another theme is allowed" do
    assert Product.new(name: "Wheat Seed", theme: @water).valid?
  end

  test "a product code is not reused with different letter case" do
    duplicate = Product.new(name: "Other Seed", product_code: "ws-01", theme: @agri)
    assert_not duplicate.valid?
    assert_match "already used by another product", duplicate.errors[:product_code].join
  end

  test "a product type name is entered once per product" do
    ProductVariety.create!(name: "Wheat - Kanishka_40 KG", product_type_code: "KAN-40", product: @wheat)

    duplicate = ProductVariety.new(name: "wheat - kanishka_40 kg", product: @wheat)
    assert_not duplicate.valid?
    assert_match "already exists for this product", duplicate.errors[:name].join

    assert_not ProductVariety.new(name: "Wheat - Lok1", product_type_code: "kan-40", product: @wheat).valid?
  end

  test "an old duplicate can still be edited when its name is not changed" do
    old_duplicate = Product.new(name: "Wheat Seed", theme: @agri)
    old_duplicate.save!(validate: false)

    old_duplicate.description = "Updated note"
    assert old_duplicate.valid?
  end
end
