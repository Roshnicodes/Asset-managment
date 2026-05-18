require "test_helper"

class AssetInsurancesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @asset = assets(:one)
    sign_in users(:one)
  end

  test "should get index" do
    get asset_insurances_url
    assert_response :success
  end

  test "should update insurance details for insured asset" do
    patch update_all_asset_insurances_url, params: {
      asset_ids: @asset.id.to_s,
      assets: {
        @asset.id.to_s => {
          insured: "true",
          insurance_company_name: "ABC Insurance",
          insurance_policy_number: "POL-100",
          insurance_date: "2026-05-13",
          insurance_expiry_date: "2027-05-13"
        }
      }
    }

    assert_redirected_to asset_insurances_url(asset_ids: @asset.id.to_s)
    @asset.reload
    assert_equal true, @asset.insured
    assert_equal "ABC Insurance", @asset.insurance_company_name
    assert_equal "POL-100", @asset.insurance_policy_number
    assert_equal Date.new(2026, 5, 13), @asset.insurance_date
    assert_equal Date.new(2027, 5, 13), @asset.insurance_expiry_date
  end

  test "should apply one insurance detail set to selected assets" do
    second_asset = assets(:two)

    patch update_all_asset_insurances_url, params: {
      bulk_insurance_update: "1",
      asset_ids: [@asset.id, second_asset.id].join(","),
      selected_asset_ids: [@asset.id.to_s, second_asset.id.to_s],
      insured: "true",
      insurance_company_name: "Batch Insurance",
      insurance_policy_number: "BATCH-100",
      insurance_date: "2026-05-13",
      insurance_expiry_date: "2027-05-13"
    }

    assert_redirected_to asset_insurances_url(asset_ids: [@asset.id, second_asset.id].join(","))

    [@asset, second_asset].each do |asset|
      asset.reload
      assert_equal true, asset.insured
      assert_equal "Batch Insurance", asset.insurance_company_name
      assert_equal "BATCH-100", asset.insurance_policy_number
      assert_equal Date.new(2026, 5, 13), asset.insurance_date
      assert_equal Date.new(2027, 5, 13), asset.insurance_expiry_date
    end
  end

  test "bulk update should require selected assets" do
    patch update_all_asset_insurances_url, params: {
      bulk_insurance_update: "1",
      asset_ids: @asset.id.to_s,
      insured: "false"
    }

    assert_redirected_to asset_insurances_url(asset_ids: @asset.id.to_s)
    assert_equal "Please select at least one asset.", flash[:alert]
  end

  test "should clear insurance details when asset is not insured" do
    @asset.update_columns(
      insured: true,
      insurance_date: Date.new(2026, 5, 13),
      insurance_company_name: "Old Company",
      insurance_policy_number: "OLD-101",
      insurance_expiry_date: Date.new(2027, 5, 13)
    )

    patch update_all_asset_insurances_url, params: {
      asset_ids: @asset.id.to_s,
      assets: {
        @asset.id.to_s => {
          insured: "false",
          insurance_company_name: "Should Clear",
          insurance_policy_number: "CLEAR-ME",
          insurance_date: "2026-05-20",
          insurance_expiry_date: "2028-05-13"
        }
      }
    }

    assert_redirected_to asset_insurances_url(asset_ids: @asset.id.to_s)
    @asset.reload
    assert_equal false, @asset.insured
    assert_nil @asset.insurance_date
    assert_nil @asset.insurance_company_name
    assert_nil @asset.insurance_policy_number
    assert_nil @asset.insurance_expiry_date
  end

  test "should render index when insured asset is missing policy details" do
    patch update_all_asset_insurances_url, params: {
      asset_ids: @asset.id.to_s,
      assets: {
        @asset.id.to_s => {
          insured: "true",
          insurance_company_name: "",
          insurance_policy_number: "",
          insurance_date: "",
          insurance_expiry_date: ""
        }
      }
    }

    assert_response :unprocessable_entity
  end
end
