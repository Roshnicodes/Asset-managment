require "test_helper"

class ProductVarietiesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  self.fixture_table_names = []

  setup do
    @stakeholder_category = StakeholderCategory.create!(name: "Product Type Batch Stakeholder")
    @theme = Theme.create!(name: "Product Type Batch Theme", stakeholder_category: @stakeholder_category)
    @product = Product.create!(
      name: "Product Type Batch Product",
      product_code: "PT-BATCH-PRODUCT",
      stakeholder_category: @stakeholder_category,
      theme: @theme
    )
    @product_variety = ProductVariety.create!(
      name: "Existing Company",
      product: @product,
      product_type_code: "PT-BATCH-EXISTING",
      stakeholder_category: @stakeholder_category
    )

    admin = EmployeeMaster.create!(
      stakeholder_category: @stakeholder_category,
      designation: "Product Type Admin",
      employee_code: "PRODUCT-TYPE-ADMIN",
      email_id: "product.type.admin@example.com",
      name: "Product Type Admin",
      user_type: "Admin"
    )

    sign_in User.find_by!(email: admin.email_id)
  end

  test "shows the new product type form" do
    get new_product_variety_url

    assert_response :success
    assert_select "[data-product-batch-form]"
    assert_select ".app-readonly-value", text: @stakeholder_category.name
  end

  test "keeps the old single product type create flow working" do
    assert_difference -> { ProductVariety.count }, 1 do
      post product_varieties_url, params: {
        product_variety: {
          name: "Single Company",
          product_id: @product.id,
          product_type_code: "PT-SINGLE-001",
          stakeholder_category_id: @stakeholder_category.id
        }
      }
    end

    assert_redirected_to product_varieties_url
    assert_equal @stakeholder_category, ProductVariety.find_by!(product_type_code: "PT-SINGLE-001").stakeholder_category
  end

  test "keeps the old single product type update flow working" do
    patch product_variety_url(@product_variety), params: {
      product_variety: {
        name: "Updated Company",
        product_id: @product.id,
        product_type_code: "PT-BATCH-EXISTING-UPDATED",
        stakeholder_category_id: @stakeholder_category.id
      }
    }

    assert_redirected_to product_varieties_url
    assert_equal "Updated Company", @product_variety.reload.name
  end

  test "keeps the old single product type destroy flow working" do
    assert_difference -> { ProductVariety.count }, -1 do
      delete product_variety_url(@product_variety)
    end

    assert_redirected_to product_varieties_url
  end

  test "creates multiple product types from one submit" do
    assert_difference -> { ProductVariety.count }, 2 do
      post product_varieties_url, params: {
        product_variety_batch: {
          product_id: @product.id,
          stakeholder_category_id: @stakeholder_category.id
        },
        product_varieties: {
          "0" => product_variety_row_attributes(name: "Solar Company", product_type_code: "PT-BATCH-001"),
          "1" => product_variety_row_attributes(name: "Water Company", product_type_code: "PT-BATCH-002")
        }
      }
    end

    assert_redirected_to product_varieties_url
    assert_equal @product, ProductVariety.find_by!(product_type_code: "PT-BATCH-001").product
    assert_equal @stakeholder_category, ProductVariety.find_by!(product_type_code: "PT-BATCH-002").stakeholder_category
  end

  test "ignores blank product type rows in a batch submit" do
    assert_difference -> { ProductVariety.count }, 1 do
      post product_varieties_url, params: {
        product_variety_batch: {
          product_id: @product.id,
          stakeholder_category_id: @stakeholder_category.id
        },
        product_varieties: {
          "0" => product_variety_row_attributes(name: "Pump Company", product_type_code: "PT-BATCH-003"),
          "1" => { name: "", product_type_code: "" }
        }
      }
    end

    assert_redirected_to product_varieties_url
  end

  test "does not save any product types when one batch row is invalid" do
    assert_no_difference -> { ProductVariety.count } do
      post product_varieties_url, params: {
        product_variety_batch: {
          product_id: @product.id,
          stakeholder_category_id: @stakeholder_category.id
        },
        product_varieties: {
          "0" => product_variety_row_attributes(name: "Valid Company", product_type_code: "PT-BATCH-004"),
          "1" => product_variety_row_attributes(name: "", product_type_code: "PT-BATCH-005")
        }
      }
    end

    assert_response :unprocessable_entity
    assert_not ProductVariety.exists?(product_type_code: "PT-BATCH-004")
    assert_select ".product-batch-row-errors", /Name can't be blank/
  end

  private

  def product_variety_row_attributes(name:, product_type_code:)
    {
      name: name,
      product_type_code: product_type_code
    }
  end
end
