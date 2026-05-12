require "test_helper"

class ProductVarietyTest < ActiveSupport::TestCase
  fixtures :products, :product_varieties

  test "normalizes product type code before validation" do
    product_variety = ProductVariety.new(name: "Premium", product: products(:one), product_type_code: "  TYPE-100  ")

    product_variety.valid?

    assert_equal "TYPE-100", product_variety.product_type_code
  end

  test "does not allow duplicate product type codes" do
    product_variety = ProductVariety.new(name: "Economy", product: products(:one), product_type_code: product_varieties(:one).product_type_code)

    assert_not product_variety.valid?
    assert_includes product_variety.errors[:product_type_code], "has already been taken"
  end
end
