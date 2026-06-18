require "csv"
require "open3"
require "tmpdir"

class OfficeStructureImporter
  SUPPORTED_EXTENSIONS = [".csv", ".xls", ".xlsx"].freeze

  Result = Struct.new(
    :office_structures_created,
    :office_structures_skipped,
    :category_masters_created,
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
      office_structures_created: 0,
      office_structures_skipped: 0,
      category_masters_created: 0,
      states_created: 0,
      districts_created: 0,
      blocks_created: 0,
      rows_skipped: 0,
      skipped_examples: []
    )

    rows.each_with_index do |row, index|
      next if row.values.all?(&:blank?)

      import_row(row, index + 2, result)
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
    CSV.parse(file.read, headers: true).map { |row| normalize_row_keys(row.to_h) }
  end

  def xlsx_rows
    require "roo"

    sheet = Roo::Spreadsheet.open(file.path, extension: :xlsx)
    headers = sheet.row(1).map { |value| normalize_header(value) }

    (2..sheet.last_row).map do |index|
      normalize_row_keys(Hash[headers.zip(sheet.row(index))])
    end
  rescue LoadError
    raise "Excel upload requires the 'roo' gem. Run bundle install, or upload a CSV file."
  end

  def xls_rows
    office_binary = %w[soffice libreoffice].find { |binary| system("which", binary, out: File::NULL, err: File::NULL) }
    raise "XLS upload requires LibreOffice. Please upload CSV or XLSX instead." if office_binary.blank?

    Dir.mktmpdir("office-structure-xls") do |dir|
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

      CSV.parse(File.read(converted_path), headers: true).map { |row| normalize_row_keys(row.to_h) }
    end
  end

  def import_row(row, row_number, result)
    stakeholder_name = clean_name(row["stakeholder"])
    category_name = clean_name(row["category"])
    office_name = clean_name(row["office"])
    parent_name = clean_name(row["parent"])
    state_name = clean_name(row["state"])
    district_name = clean_name(row["district"])
    block_name = clean_name(row["block"])

    if stakeholder_name.blank?
      skip_row(result, row_number, "stakeholder missing")
      return
    end

    if category_name.blank?
      skip_row(result, row_number, "category name missing")
      return
    end

    stakeholder = find_stakeholder(stakeholder_name)
    unless stakeholder
      skip_row(result, row_number, "stakeholder '#{stakeholder_name}' not found")
      return
    end

    category_master, category_created = find_or_create_category_master(category_name, stakeholder)
    result.category_masters_created += 1 if category_created

    state, state_created = find_or_create_state(state_name, result)
    result.states_created += 1 if state_created

    district, district_created = find_or_create_district(district_name, state)
    result.districts_created += 1 if district_created

    block, block_created = find_or_create_block(block_name, district)
    result.blocks_created += 1 if block_created

    parent = find_parent(parent_name, stakeholder)

    office = OfficeCategory.new(
      stakeholder_category: stakeholder,
      office_category_master: category_master,
      parent: parent,
      state: state,
      district: district,
      block: block,
      name: office_name.presence
    )
    office.allow_blank_import_location = true
    office.valid?

    if existing_office?(office)
      result.office_structures_skipped += 1
      return
    end

    office.save!
    result.office_structures_created += 1
  end

  def find_stakeholder(name)
    StakeholderCategory.find_by("LOWER(TRIM(name)) = ?", name.downcase)
  end

  def find_or_create_category_master(name, stakeholder)
    master = stakeholder.office_category_masters.find_by("LOWER(TRIM(name)) = ?", name.downcase)
    return [master, false] if master

    [stakeholder.office_category_masters.create!(name: name), true]
  end

  def find_or_create_state(name, _result)
    return [nil, false] if name.blank?

    state = State.find_by("LOWER(TRIM(name)) = ?", name.downcase)
    return [state, false] if state

    [State.create!(name: name), true]
  end

  def find_or_create_district(name, state)
    return [nil, false] if name.blank?
    return [nil, false] if state.blank?

    district = state.districts.find_by("LOWER(TRIM(name)) = ?", name.downcase)
    return [district, false] if district

    [state.districts.create!(name: name), true]
  end

  def find_or_create_block(name, district)
    return [nil, false] if name.blank?
    return [nil, false] if district.blank?

    block = district.blocks.find_by("LOWER(TRIM(name)) = ?", name.downcase)
    return [block, false] if block

    [district.blocks.create!(name: name), true]
  end

  def find_parent(name, stakeholder)
    return if name.blank?

    offices = stakeholder.office_categories.includes(:office_category_master, :state, :district, :block)
    offices.find do |office|
      office.name.to_s.strip.casecmp(name).zero? ||
        office.display_name.to_s.strip.casecmp(name).zero?
    end
  end

  def existing_office?(office)
    OfficeCategory.where(
      stakeholder_category_id: office.stakeholder_category_id,
      office_category_master_id: office.office_category_master_id,
      parent_id: office.parent_id,
      state_id: office.state_id,
      district_id: office.district_id,
      block_id: office.block_id
    ).where("LOWER(TRIM(name)) = ?", office.name.to_s.strip.downcase).exists?
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
    when "stakeholder", "stakeholder category", "stakeholder name" then "stakeholder"
    when "category", "category name", "office category", "office category master", "office level" then "category"
    when "office", "office name", "name", "office structure name" then "office"
    when "parent", "parent office", "parent office name" then "parent"
    when "state", "state name" then "state"
    when "district", "district name" then "district"
    when "block", "block name" then "block"
    else value.tr(" ", "_")
    end
  end

  def clean_name(value)
    value.to_s.strip.gsub(/\s+/, " ")
  end
end
