require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  self.fixture_table_names = []

  setup do
    @stakeholder_category = StakeholderCategory.create!(name: "Product Batch Stakeholder")
    @theme = Theme.create!(name: "Product Batch Theme", stakeholder_category: @stakeholder_category)
    admin = EmployeeMaster.create!(
      stakeholder_category: @stakeholder_category,
      designation: "Product Admin",
      employee_code: "PRODUCT-ADMIN",
      email_id: "product.admin@example.com",
      name: "Product Admin",
      user_type: "Admin"
    )

    sign_in User.find_by!(email: admin.email_id)
  end

  test "creates multiple products from one submit" do
    assert_difference -> { Product.count }, 2 do
      post products_url, params: {
        product_batch: {
          theme_id: @theme.id,
          stakeholder_category_id: @stakeholder_category.id
        },
        products: {
          "0" => product_row_attributes(name: "Solar Pump", product_code: "P-BATCH-001"),
          "1" => product_row_attributes(name: "Water Tank", product_code: "P-BATCH-002")
        }
      }
    end

    assert_redirected_to products_url
    assert_equal @stakeholder_category, Product.find_by!(product_code: "P-BATCH-001").stakeholder_category
    assert_equal @stakeholder_category, Product.find_by!(product_code: "P-BATCH-002").stakeholder_category
  end

  test "ignores blank product rows in a batch submit" do
    assert_difference -> { Product.count }, 1 do
      post products_url, params: {
        product_batch: {
          theme_id: @theme.id,
          stakeholder_category_id: @stakeholder_category.id
        },
        products: {
          "0" => product_row_attributes(name: "Irrigation Kit", product_code: "P-BATCH-003"),
          "1" => { name: "", product_code: "", description: "" }
        }
      }
    end

    assert_redirected_to products_url
  end

  test "does not save any products when one batch row is invalid" do
    assert_no_difference -> { Product.count } do
      post products_url, params: {
        product_batch: {
          theme_id: @theme.id,
          stakeholder_category_id: @stakeholder_category.id
        },
        products: {
          "0" => product_row_attributes(name: "Valid Product", product_code: "P-BATCH-004"),
          "1" => product_row_attributes(name: "", product_code: "P-BATCH-005")
        }
      }
    end

    assert_response :success
    assert_not Product.exists?(product_code: "P-BATCH-004")
    assert_select ".product-batch-row-errors", /Name can't be blank/
  end

  private

  def product_row_attributes(name:, product_code:)
    {
      description: "#{name} description",
      name: name,
      product_code: product_code
    }
  end
end
