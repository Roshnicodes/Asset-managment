require "test_helper"

class OfficeStructureImporterTest < ActiveSupport::TestCase
  test "imports office structure from csv" do
    stakeholder = StakeholderCategory.create!(name: "Office Import Stakeholder")

    file = Tempfile.new(["office-structure-import", ".csv"])
    file.write <<~CSV
      Stakeholder,Category Name,Office Name,State,District,Block
      #{stakeholder.name},Regional Office,North Office,Test Office State,Test Office District,Test Office Block
    CSV
    file.rewind

    upload = ActionDispatch::Http::UploadedFile.new(
      tempfile: file,
      filename: "office-structure-import.csv",
      type: "text/csv"
    )

    result = OfficeStructureImporter.call(upload)

    office = OfficeCategory.find_by!(name: "North Office")

    assert_equal 1, result.office_structures_created
    assert_equal 1, result.category_masters_created
    assert_equal stakeholder, office.stakeholder_category
    assert_equal "Regional Office", office.office_category_master.name
    assert_equal "Test Office State", office.state.name
    assert_equal "Test Office District", office.district.name
    assert_equal "Test Office Block", office.block.name
  ensure
    file&.close!
  end

  test "imports office structure and leaves location blank when state is missing" do
    stakeholder = StakeholderCategory.create!(name: "Office Import Blank Location Stakeholder")

    file = Tempfile.new(["office-structure-blank-location-import", ".csv"])
    file.write <<~CSV
      Stakeholder,Category Name,Office Name,State,District,Block
      #{stakeholder.name},District Office,Office Without State,,Some District,Some Block
    CSV
    file.rewind

    upload = ActionDispatch::Http::UploadedFile.new(
      tempfile: file,
      filename: "office-structure-blank-location-import.csv",
      type: "text/csv"
    )

    result = OfficeStructureImporter.call(upload)

    office = OfficeCategory.find_by!(name: "Office Without State")

    assert_equal 1, result.office_structures_created
    assert_equal 0, result.rows_skipped
    assert_nil office.state
    assert_nil office.district
    assert_nil office.block
  ensure
    file&.close!
  end

  test "imports office structure and leaves parent blank when parent is not found" do
    stakeholder = StakeholderCategory.create!(name: "Office Import Missing Parent Stakeholder")

    file = Tempfile.new(["office-structure-missing-parent-import", ".csv"])
    file.write <<~CSV
      Stakeholder,Category Name,Office Name,Parent Office
      #{stakeholder.name},Regional Office,Office Without Parent,Unknown Parent
    CSV
    file.rewind

    upload = ActionDispatch::Http::UploadedFile.new(
      tempfile: file,
      filename: "office-structure-missing-parent-import.csv",
      type: "text/csv"
    )

    result = OfficeStructureImporter.call(upload)

    office = OfficeCategory.find_by!(name: "Office Without Parent")

    assert_equal 1, result.office_structures_created
    assert_equal 0, result.rows_skipped
    assert_nil office.parent
  ensure
    file&.close!
  end
end
