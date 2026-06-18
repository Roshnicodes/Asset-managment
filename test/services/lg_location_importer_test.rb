require "test_helper"

class LgLocationImporterTest < ActiveSupport::TestCase
  test "imports state district and block hierarchy from csv" do
    file = Tempfile.new(["lg-location-import", ".csv"])
    file.write <<~CSV
      State Name,District Name,Block Name
      Test Import State,Test Import District,Test Import Block
      Test Import State,Test Import District,Second Test Import Block
    CSV
    file.rewind

    upload = ActionDispatch::Http::UploadedFile.new(
      tempfile: file,
      filename: "lg-location-import.csv",
      type: "text/csv"
    )

    result = LgLocationImporter.call(upload)

    state = State.find_by!(name: "Test Import State")
    district = state.districts.find_by!(name: "Test Import District")

    assert_equal 1, result.states_created
    assert_equal 1, result.districts_created
    assert_equal 2, result.blocks_created
    assert_equal 0, result.rows_skipped
    assert_equal ["Second Test Import Block", "Test Import Block"], district.blocks.order(:name).pluck(:name)
  ensure
    file&.close!
  end

  test "imports state district and block codes from report style sheet" do
    file = Tempfile.new(["lg-location-report-import", ".csv"])
    file.write <<~CSV
      ,,,,,
      ,,,,,
      ,,,All Blocks of Madhya Pradesh State,,
      ,,,,,
      State Code,State Name,District Code,District,Block Code,Block Name
      23,Madhya,667,Agar-Malwa,4000,Agar
      23,Madhya,667,Agar-Malwa,4000,Agar
    CSV
    file.rewind

    upload = ActionDispatch::Http::UploadedFile.new(
      tempfile: file,
      filename: "lg-location-report-import.csv",
      type: "text/csv"
    )

    result = LgLocationImporter.call(upload)

    state = State.find_by!(code: "23")
    district = state.districts.find_by!(code: "667")
    block = district.blocks.find_by!(code: "4000")

    assert_equal "Madhya", state.name
    assert_equal "Agar-Malwa", district.name
    assert_equal "Agar", block.name
    assert_equal 1, result.states_created
    assert_equal 1, result.districts_created
    assert_equal 1, result.blocks_created
  ensure
    file&.close!
  end

  test "reports skipped rows with row numbers when required data is missing" do
    file = Tempfile.new(["lg-location-invalid-import", ".csv"])
    file.write <<~CSV
      State Name,District Name,Block Name
      ,Missing State District,Missing State Block
    CSV
    file.rewind

    upload = ActionDispatch::Http::UploadedFile.new(
      tempfile: file,
      filename: "lg-location-invalid-import.csv",
      type: "text/csv"
    )

    result = LgLocationImporter.call(upload)

    assert_equal 0, result.states_created
    assert_equal 0, result.districts_created
    assert_equal 0, result.blocks_created
    assert_equal 1, result.rows_skipped
    assert_equal ["row 2: state name missing"], result.skipped_examples
  ensure
    file&.close!
  end
end
