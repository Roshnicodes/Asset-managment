require "csv"
require "open3"
require "tmpdir"

class LgLocationImporter
  SUPPORTED_EXTENSIONS = [".csv", ".xls", ".xlsx"].freeze

  Result = Struct.new(
    :states_created,
    :districts_created,
    :blocks_created,
    :rows_skipped,
    :skipped_examples,
    keyword_init: true
  )

  def self.call(file)
    new(file).call
  end

  def initialize(file)
    @file = file
  end

  def call
    validate_file!

    result = Result.new(
      states_created: 0,
      districts_created: 0,
      blocks_created: 0,
      rows_skipped: 0,
      skipped_examples: []
    )

    rows.each do |row|
      row_number = row.delete("__row_number")
      next if row.values.all?(&:blank?)

      import_row(row, row_number, result)
    end

    result
  end

  private

  attr_reader :file

  def validate_file!
    return if SUPPORTED_EXTENSIONS.include?(extension)

    raise "Please upload a CSV, XLS, or XLSX file."
  end

  def extension
    @extension ||= File.extname(file.original_filename).downcase
  end

  def rows
    @rows ||=
      case extension
      when ".csv" then csv_rows
      when ".xls" then xls_rows
      else xlsx_rows
      end
  end

  def csv_rows
    rows_from_matrix(CSV.parse(file.read))
  end

  def xlsx_rows
    require "roo"

    sheet = Roo::Spreadsheet.open(file.path, extension: :xlsx)
    rows_from_matrix((1..sheet.last_row).map { |index| sheet.row(index) })
  rescue LoadError
    raise "Excel upload requires the 'roo' gem. Run bundle install, or upload a CSV file."
  end

  def xls_rows
    office_binary = %w[soffice libreoffice].find { |binary| system("which", binary, out: File::NULL, err: File::NULL) }
    raise "XLS upload requires LibreOffice. Please upload CSV or XLSX instead." if office_binary.blank?

    Dir.mktmpdir("lg-location-xls") do |dir|
      profile_dir = File.join(dir, "lo-profile")
      stdout, stderr, status = Open3.capture3(
        office_binary,
        "--headless",
        "-env:UserInstallation=file://#{profile_dir}",
        "--convert-to",
        "csv",
        "--outdir",
        dir,
        file.path
      )

      unless status.success?
        raise "XLS conversion failed: #{stderr.presence || stdout.presence || 'LibreOffice could not convert the file.'}"
      end

      converted_path = Dir.glob(File.join(dir, "*.csv")).first
      raise "XLS conversion failed: CSV output was not created." if converted_path.blank?

      rows_from_matrix(CSV.parse(File.read(converted_path)))
    end
  end

  def import_row(row, row_number, result)
    state_code = clean_code(row["state_code"])
    state_name = clean_name(row["state"])
    district_code = clean_code(row["district_code"])
    district_name = clean_name(row["district"])
    block_code = clean_code(row["block_code"])
    block_name = clean_name(row["block"])

    return if [state_code, state_name, district_code, district_name, block_code, block_name].all?(&:blank?)

    if state_name.blank?
      state = State.find_by(code: state_code) if state_code.present?
      if state.blank?
        skip_row(result, row_number, "state name missing")
        return
      end
      state_created = false
    else
      state, state_created = find_or_create_state(state_name, state_code)
    end

    result.states_created += 1 if state_created

    return if district_name.blank?

    district, district_created = find_or_create_district(district_name, district_code, state)
    result.districts_created += 1 if district_created

    return if block_name.blank?

    _block, block_created = find_or_create_block(block_name, block_code, district)
    result.blocks_created += 1 if block_created
  end

  def find_or_create_state(name, code)
    state = State.find_by(code: code) if code.present?
    state ||= State.find_by("LOWER(TRIM(name)) = ?", name.downcase)
    if state
      state.update!(code: code) if code.present? && state.code.blank?
      return [state, false]
    end

    [State.create!(name: name, code: code), true]
  end

  def find_or_create_district(name, code, state)
    district = state.districts.find_by(code: code) if code.present?
    district ||= state.districts.find_by("LOWER(TRIM(name)) = ?", name.downcase)
    if district
      district.update!(code: code) if code.present? && district.code.blank?
      return [district, false]
    end

    [state.districts.create!(name: name, code: code), true]
  end

  def find_or_create_block(name, code, district)
    block = district.blocks.find_by(code: code) if code.present?
    block ||= district.blocks.find_by("LOWER(TRIM(name)) = ?", name.downcase)
    if block
      block.update!(code: code) if code.present? && block.code.blank?
      return [block, false]
    end

    [district.blocks.create!(name: name, code: code), true]
  end

  def skip_row(result, row_number, reason)
    result.rows_skipped += 1
    result.skipped_examples << "row #{row_number}: #{reason}" if result.skipped_examples.size < 10
  end

  def normalize_row_keys(row)
    row.transform_keys { |key| normalize_header(key) }.reject { |key, _value| key.blank? }
  end

  def normalize_header(header)
    value = header.to_s.strip.downcase.gsub(/\s+/, " ")

    case value
    when "state", "state name" then "state"
    when "state code" then "state_code"
    when "district", "district name" then "district"
    when "district code" then "district_code"
    when "block", "block name" then "block"
    when "block code" then "block_code"
    else value.tr(" ", "_")
    end
  end

  def rows_from_matrix(matrix)
    header_index = matrix.find_index { |row| import_header_row?(row) }
    raise "Import header row not found. Please include State Name, District Name, and Block Name columns." if header_index.nil?

    headers = matrix[header_index].map { |value| normalize_header(value) }
    matrix[(header_index + 1)..].to_a.each_with_index.map do |row, index|
      normalize_row_keys(Hash[headers.zip(row)]).merge("__row_number" => header_index + index + 2)
    end
  end

  def import_header_row?(row)
    headers = row.map { |value| normalize_header(value) }
    headers.include?("state") && headers.include?("district") && headers.include?("block")
  end

  def clean_name(value)
    value.to_s.strip.gsub(/\s+/, " ")
  end

  def clean_code(value)
    code = value.is_a?(Numeric) ? value.to_i.to_s : value.to_s.strip
    code.sub(/\A(\d+)\.0\z/, "\\1").presence
  end
end
