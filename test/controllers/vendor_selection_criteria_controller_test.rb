require "test_helper"

class VendorSelectionCriteriaControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  self.fixture_table_names = []

  setup do
    stakeholder_category = StakeholderCategory.create!(name: "Vendor Criteria Stakeholder")
    @theme = Theme.create!(name: "Vendor Criteria Theme", stakeholder_category: stakeholder_category)
    @vendor_selection_criterion = VendorSelectionCriterion.create!(
      criteria: "Existing evaluation criteria",
      theme: @theme
    )

    admin = EmployeeMaster.create!(
      stakeholder_category: stakeholder_category,
      designation: "Vendor Criteria Admin",
      employee_code: "VENDOR-CRITERIA-ADMIN",
      email_id: "vendor.criteria.admin@example.com",
      name: "Vendor Criteria Admin",
      user_type: "Admin"
    )

    sign_in User.find_by!(email: admin.email_id)
  end

  test "shows the new vendor selection criteria batch form" do
    get new_vendor_selection_criterion_url

    assert_response :success
    assert_select "[data-product-batch-form]"
    assert_select "[data-add-product-row]"
  end

  test "keeps the old single criteria create flow working" do
    assert_difference -> { VendorSelectionCriterion.count }, 1 do
      post vendor_selection_criteria_url, params: {
        vendor_selection_criterion: {
          criteria: "Single criteria",
          theme_id: @theme.id
        }
      }
    end

    assert_redirected_to vendor_selection_criteria_url
    assert_equal @theme, VendorSelectionCriterion.find_by!(criteria: "Single criteria").theme
  end

  test "keeps the old single criteria update flow working" do
    patch vendor_selection_criterion_url(@vendor_selection_criterion), params: {
      vendor_selection_criterion: {
        criteria: "Updated criteria",
        theme_id: @theme.id
      }
    }

    assert_redirected_to vendor_selection_criteria_url
    assert_equal "Updated criteria", @vendor_selection_criterion.reload.criteria
  end

  test "keeps the old single criteria destroy flow working" do
    assert_difference -> { VendorSelectionCriterion.count }, -1 do
      delete vendor_selection_criterion_url(@vendor_selection_criterion)
    end

    assert_redirected_to vendor_selection_criteria_url
  end

  test "creates multiple criteria from one submit" do
    assert_difference -> { VendorSelectionCriterion.count }, 2 do
      post vendor_selection_criteria_url, params: {
        vendor_selection_criteria_batch: {
          theme_id: @theme.id
        },
        vendor_selection_criteria: {
          "0" => { criteria: "Technical score" },
          "1" => { criteria: "Financial score" }
        }
      }
    end

    assert_redirected_to vendor_selection_criteria_url
    assert_equal @theme, VendorSelectionCriterion.find_by!(criteria: "Technical score").theme
    assert_equal @theme, VendorSelectionCriterion.find_by!(criteria: "Financial score").theme
  end

  test "ignores blank criteria rows in a batch submit" do
    assert_difference -> { VendorSelectionCriterion.count }, 1 do
      post vendor_selection_criteria_url, params: {
        vendor_selection_criteria_batch: {
          theme_id: @theme.id
        },
        vendor_selection_criteria: {
          "0" => { criteria: "Eligibility score" },
          "1" => { criteria: "" }
        }
      }
    end

    assert_redirected_to vendor_selection_criteria_url
  end

  test "does not save criteria rows when the batch theme is missing" do
    assert_no_difference -> { VendorSelectionCriterion.count } do
      post vendor_selection_criteria_url, params: {
        vendor_selection_criteria_batch: {
          theme_id: ""
        },
        vendor_selection_criteria: {
          "0" => { criteria: "Valid looking criteria" },
          "1" => { criteria: "Another valid looking criteria" }
        }
      }
    end

    assert_response :unprocessable_entity
    assert_not VendorSelectionCriterion.exists?(criteria: "Valid looking criteria")
    assert_select ".product-batch-row-errors", /Theme must exist/
  end
end
