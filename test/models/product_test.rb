require "test_helper"

class ProductTest < ActiveSupport::TestCase
  fixtures :themes, :products

  test "normalizes product code before validation" do
    product = Product.new(name: "Solar Pump", theme: themes(:one), product_code: "  PROD-100  ")

    product.valid?

    assert_equal "PROD-100", product.product_code
  end

  test "does not allow duplicate product codes" do
    product = Product.new(name: "Solar Panel", theme: themes(:one), product_code: products(:one).product_code)

    assert_not product.valid?
    assert_includes product.errors[:product_code], "has already been taken"
  end
end
