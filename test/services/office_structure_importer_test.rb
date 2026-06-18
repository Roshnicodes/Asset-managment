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
end
