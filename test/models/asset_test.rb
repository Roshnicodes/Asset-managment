require "test_helper"

class AssetTest < ActiveSupport::TestCase
  test "reloads asset column information when structured code columns are missing" do
    reload_count = 0
    asset_singleton = class << Asset; self; end
    asset_singleton.alias_method :__asset_test_original_attribute_names, :attribute_names
    asset_singleton.alias_method :__asset_test_original_reset_column_information, :reset_column_information

    asset_singleton.define_method(:attribute_names) do
      if reload_count.zero?
        %w[id name product_id]
      else
        %w[id name product_id stakeholder_category_id primary_office_category_id secondary_office_category_id asset_code_date insured insurance_date insurance_company_name insurance_policy_number insurance_expiry_date]
      end
    end

    asset_singleton.define_method(:reset_column_information) do
      reload_count += 1
    end

    Asset.ensure_structured_code_columns_loaded!

    assert_equal 1, reload_count
  ensure
    asset_singleton.alias_method :attribute_names, :__asset_test_original_attribute_names
    asset_singleton.alias_method :reset_column_information, :__asset_test_original_reset_column_information
    asset_singleton.remove_method :__asset_test_original_attribute_names
    asset_singleton.remove_method :__asset_test_original_reset_column_information
  end

  test "generates structured asset code from stakeholder, offices, product type code, item no, and date" do
    stakeholder = StakeholderCategory.create!(name: "ASA")
    state = State.create!(name: "Madhya Pradesh")
    first_district = District.create!(name: "Neemuch", state: state)
    second_district = District.create!(name: "Ratlam", state: state)
    first_master = OfficeCategoryMaster.create!(stakeholder_category: stakeholder, name: "TO")
    second_master = OfficeCategoryMaster.create!(stakeholder_category: stakeholder, name: "FCO")
    first_office = OfficeCategory.create!(stakeholder_category: stakeholder, office_category_master: first_master, district: first_district)
    second_office = OfficeCategory.create!(stakeholder_category: stakeholder, office_category_master: second_master, district: second_district)
    theme = Theme.create!(name: "Furniture", stakeholder_category: stakeholder)
    product = Product.create!(name: "Chair Catalog", product_code: "CHR-001", theme: theme)
    ProductVariety.create!(name: "Chair Type", product_type_code: "TYPE-CHR", product: product)

    asset = Asset.create!(
      name: "Chair",
      product: product,
      unique_product_code: "M01",
      stakeholder_category: stakeholder,
      primary_office_category: first_office,
      secondary_office_category: second_office,
      asset_code_date: Date.new(2022, 1, 12)
    )

    assert_equal "ASA/TO-Neemuch/FCO-Ratlam/TYPE-CHR/M01/Dt.12.01.2022/2021-2022", asset.asset_code
  end

  test "defaults item no from the selected product code" do
    stakeholder = StakeholderCategory.create!(name: "ASA")
    state = State.create!(name: "Madhya Pradesh")
    first_district = District.create!(name: "Neemuch", state: state)
    second_district = District.create!(name: "Ratlam", state: state)
    first_master = OfficeCategoryMaster.create!(stakeholder_category: stakeholder, name: "TO")
    second_master = OfficeCategoryMaster.create!(stakeholder_category: stakeholder, name: "FCO")
    first_office = OfficeCategory.create!(stakeholder_category: stakeholder, office_category_master: first_master, district: first_district)
    second_office = OfficeCategory.create!(stakeholder_category: stakeholder, office_category_master: second_master, district: second_district)
    theme = Theme.create!(name: "IT", stakeholder_category: stakeholder)
    product = Product.create!(name: "Laptop Catalog", product_code: "LAP-001", theme: theme)
    ProductVariety.create!(name: "Laptop Type", product_type_code: "TYPE-LAP", product: product)

    asset = Asset.create!(
      name: "Laptop",
      product: product,
      stakeholder_category: stakeholder,
      primary_office_category: first_office,
      secondary_office_category: second_office,
      asset_code_date: Date.new(2022, 1, 12)
    )

    assert_equal "LAP-001", asset.unique_product_code
    assert_equal "ASA/TO-Neemuch/FCO-Ratlam/TYPE-LAP/LAP-001/Dt.12.01.2022/2021-2022", asset.asset_code
  end

  test "builds financial year label from asset code date" do
    assert_equal "2025-2026", Asset.financial_year_label(Date.new(2026, 3, 31))
    assert_equal "2026-2027", Asset.financial_year_label(Date.new(2026, 4, 1))
    assert_equal "2026-2027", Asset.financial_year_label(Date.new(2026, 5, 13))
  end

  test "places financial year after the date segment" do
    assert_equal "ASA/FCO-Shahdol/TO-Sohagpur/HD/HD01/Dt.13.05.2026/2026-2027",
                 Asset.generate_asset_code(
                   stakeholder_name: "ASA",
                   primary_location: "FCO-Shahdol",
                   secondary_location: "TO-Sohagpur",
                   product_type_code: "HD",
                   item_number: "HD01",
                   code_date: Date.new(2026, 5, 13)
                 )
  end

  test "defaults serial number sequentially when blank" do
    stakeholder = StakeholderCategory.create!(name: "ASA")
    state = State.create!(name: "Madhya Pradesh")
    first_district = District.create!(name: "Neemuch", state: state)
    second_district = District.create!(name: "Ratlam", state: state)
    first_master = OfficeCategoryMaster.create!(stakeholder_category: stakeholder, name: "TO")
    second_master = OfficeCategoryMaster.create!(stakeholder_category: stakeholder, name: "FCO")
    first_office = OfficeCategory.create!(stakeholder_category: stakeholder, office_category_master: first_master, district: first_district)
    second_office = OfficeCategory.create!(stakeholder_category: stakeholder, office_category_master: second_master, district: second_district)
    theme = Theme.create!(name: "IT", stakeholder_category: stakeholder)
    product = Product.create!(name: "Monitor Catalog", product_code: "MON-001", theme: theme)
    ProductVariety.create!(name: "Monitor Type", product_type_code: "TYPE-MON", product: product)

    first_asset = Asset.create!(
      name: "Monitor",
      product: product,
      unique_product_code: "ITEM-01",
      stakeholder_category: stakeholder,
      primary_office_category: first_office,
      secondary_office_category: second_office,
      asset_code_date: Date.new(2022, 1, 12)
    )

    second_asset = Asset.create!(
      name: "Monitor",
      product: product,
      unique_product_code: "ITEM-02",
      stakeholder_category: stakeholder,
      primary_office_category: first_office,
      secondary_office_category: second_office,
      asset_code_date: Date.new(2022, 1, 12)
    )

    assert_equal "1", first_asset.serial_number
    assert_equal "2", second_asset.serial_number
  end

  test "requires office locations to belong to selected stakeholder" do
    stakeholder = StakeholderCategory.create!(name: "ASA")
    other_stakeholder = StakeholderCategory.create!(name: "WRD")
    state = State.create!(name: "Madhya Pradesh")
    district = District.create!(name: "Neemuch", state: state)
    primary_master = OfficeCategoryMaster.create!(stakeholder_category: stakeholder, name: "TO")
    secondary_master = OfficeCategoryMaster.create!(stakeholder_category: other_stakeholder, name: "FCO")
    primary_office = OfficeCategory.create!(stakeholder_category: stakeholder, office_category_master: primary_master, district: district)
    secondary_office = OfficeCategory.create!(stakeholder_category: other_stakeholder, office_category_master: secondary_master, district: district)
    theme = Theme.create!(name: "Furniture", stakeholder_category: stakeholder)
    product = Product.create!(name: "Desk Catalog", theme: theme)

    asset = Asset.new(
      name: "Desk",
      product: product,
      unique_product_code: "D01",
      stakeholder_category: stakeholder,
      primary_office_category: primary_office,
      secondary_office_category: secondary_office,
      asset_code_date: Date.new(2022, 1, 12)
    )

    assert_not asset.valid?
    assert_includes asset.errors[:secondary_office_category_id], "must belong to the selected stakeholder"
  end

  test "allows duplicate asset code and item no for matching assets" do
    stakeholder = StakeholderCategory.create!(name: "ASA")
    state = State.create!(name: "Madhya Pradesh")
    first_district = District.create!(name: "Neemuch", state: state)
    second_district = District.create!(name: "Ratlam", state: state)
    first_master = OfficeCategoryMaster.create!(stakeholder_category: stakeholder, name: "TO")
    second_master = OfficeCategoryMaster.create!(stakeholder_category: stakeholder, name: "FCO")
    first_office = OfficeCategory.create!(stakeholder_category: stakeholder, office_category_master: first_master, district: first_district)
    second_office = OfficeCategory.create!(stakeholder_category: stakeholder, office_category_master: second_master, district: second_district)
    theme = Theme.create!(name: "IT", stakeholder_category: stakeholder)
    product = Product.create!(name: "Laptop Catalog", product_code: "LAP-001", theme: theme)
    ProductVariety.create!(name: "Laptop Type", product_type_code: "TYPE-LAP", product: product)

    first_asset = Asset.create!(
      name: "Laptop",
      product: product,
      unique_product_code: "ITEM-01",
      stakeholder_category: stakeholder,
      primary_office_category: first_office,
      secondary_office_category: second_office,
      asset_code_date: Date.new(2022, 1, 12)
    )

    duplicate_asset = Asset.new(
      name: "Laptop",
      product: product,
      unique_product_code: "ITEM-01",
      stakeholder_category: stakeholder,
      primary_office_category: first_office,
      secondary_office_category: second_office,
      asset_code_date: Date.new(2022, 1, 12)
    )

    assert duplicate_asset.valid?
    assert_equal first_asset.asset_code, duplicate_asset.asset_code
  end

  test "requires serial number to be unique when present" do
    stakeholder = StakeholderCategory.create!(name: "ASA")
    state = State.create!(name: "Madhya Pradesh")
    first_district = District.create!(name: "Neemuch", state: state)
    second_district = District.create!(name: "Ratlam", state: state)
    first_master = OfficeCategoryMaster.create!(stakeholder_category: stakeholder, name: "TO")
    second_master = OfficeCategoryMaster.create!(stakeholder_category: stakeholder, name: "FCO")
    first_office = OfficeCategory.create!(stakeholder_category: stakeholder, office_category_master: first_master, district: first_district)
    second_office = OfficeCategory.create!(stakeholder_category: stakeholder, office_category_master: second_master, district: second_district)
    theme = Theme.create!(name: "IT", stakeholder_category: stakeholder)
    product = Product.create!(name: "Printer Catalog", product_code: "PRN-001", theme: theme)
    ProductVariety.create!(name: "Printer Type", product_type_code: "TYPE-PRN", product: product)

    Asset.create!(
      name: "Printer",
      product: product,
      serial_number: "SR-100",
      unique_product_code: "ITEM-PRN",
      stakeholder_category: stakeholder,
      primary_office_category: first_office,
      secondary_office_category: second_office,
      asset_code_date: Date.new(2022, 1, 12)
    )

    asset = Asset.new(
      name: "Printer Clone",
      product: product,
      serial_number: "SR-100",
      unique_product_code: "ITEM-PRN-2",
      stakeholder_category: stakeholder,
      primary_office_category: first_office,
      secondary_office_category: second_office,
      asset_code_date: Date.new(2022, 1, 13)
    )

    assert_not asset.valid?
    assert_includes asset.errors[:serial_number], "has already been taken"
  end

  test "requires insurance details when insurance is marked yes" do
    asset = assets(:one)
    asset.insured = true
    asset.insurance_date = nil
    asset.insurance_company_name = nil
    asset.insurance_policy_number = nil
    asset.insurance_expiry_date = nil

    assert_not asset.valid?
    assert_includes asset.errors[:insurance_date], "can't be blank"
    assert_includes asset.errors[:insurance_company_name], "can't be blank"
    assert_includes asset.errors[:insurance_policy_number], "can't be blank"
    assert_includes asset.errors[:insurance_expiry_date], "can't be blank"
  end

  test "clears insurance details when insurance is marked no" do
    asset = assets(:one)
    asset.insured = false
    asset.insurance_date = Date.new(2026, 5, 13)
    asset.insurance_company_name = "ABC Insurance"
    asset.insurance_policy_number = "POL-100"
    asset.insurance_expiry_date = Date.new(2027, 5, 13)

    assert asset.valid?
    assert_nil asset.insurance_date
    assert_nil asset.insurance_company_name
    assert_nil asset.insurance_policy_number
    assert_nil asset.insurance_expiry_date
  end

  test "requires insurance expiry date to be on or after insurance date" do
    asset = assets(:one)
    asset.insured = true
    asset.insurance_date = Date.new(2026, 5, 13)
    asset.insurance_company_name = "ABC Insurance"
    asset.insurance_policy_number = "POL-100"
    asset.insurance_expiry_date = Date.new(2026, 5, 12)

    assert_not asset.valid?
    assert_includes asset.errors[:insurance_expiry_date], "must be on or after the insurance date"
  end
end
