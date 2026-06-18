class EmployeeMastersController < ApplicationController
  require "csv"
  require "open3"
  require "tmpdir"
  before_action :set_employee_master, only: %i[edit update destroy reset_login_password]

  def index
    @employee_masters = EmployeeMaster.includes(:stakeholder_category).order(:name)
  end

  def export
    employee_masters = EmployeeMaster.includes(:stakeholder_category, :state, :district, :block).order(:name)

    send_data(
      generate_csv(employee_masters),
      filename: "employee_masters_#{Date.current.strftime('%Y%m%d')}.csv",
      type: "text/csv; charset=utf-8"
    )
  end

  def new
    @employee_master = EmployeeMaster.new
    load_location_collections
  end

  def edit
    load_location_collections
  end

  def create
    @employee_master = EmployeeMaster.new(employee_master_params)

    if @employee_master.save
      redirect_to employee_masters_path, notice: "Employee master created successfully. Employee-code login access is ready."
    else
      load_location_collections
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @employee_master.update(employee_master_params)
      redirect_to employee_masters_path, notice: "Employee master updated successfully. Employee-code login access has been synced."
    else
      load_location_collections
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @employee_master.destroy
      redirect_to employee_masters_path, notice: "Employee master deleted successfully.", status: :see_other
    else
      redirect_to employee_masters_path, alert: employee_delete_blocked_message, status: :see_other
    end
  rescue ActiveRecord::InvalidForeignKey
    redirect_to employee_masters_path, alert: employee_delete_blocked_message, status: :see_other
  end

  def destroy_selected
    employee_master_ids = selected_ids(:employee_master_ids)
    if employee_master_ids.blank?
      redirect_to employee_masters_path, alert: "Please select at least one employee to delete.", status: :see_other
      return
    end

    deleted_count = 0
    blocked_names = []

    EmployeeMaster.where(id: employee_master_ids).each do |employee|
      if employee.destroy
        deleted_count += 1
      else
        blocked_names << employee.name
      end
    rescue ActiveRecord::DeleteRestrictionError, ActiveRecord::InvalidForeignKey, ActiveRecord::RecordNotDestroyed
      blocked_names << employee.name
    end

    redirect_to employee_masters_path,
                flash: employee_bulk_delete_flash(deleted_count, blocked_names),
                status: :see_other
  end

  def reset_login_password
    if @employee_master.email_id.blank? || @employee_master.employee_code.blank?
      redirect_to employee_masters_path, alert: "This employee needs both an employee code and email ID for login reset."
      return
    end

    default_password = EmployeeLoginProvisioner::DEFAULT_PASSWORD
    EmployeeLoginProvisioner.provision_for!(
      @employee_master,
      password: default_password,
      password_confirmation: default_password
    )

    redirect_to employee_masters_path, notice: "Login password reset to #{default_password} for #{@employee_master.employee_code}."
  rescue StandardError => error
    redirect_to employee_masters_path, alert: "Login password reset failed: #{error.message}"
  end

  def import
    if params[:file].blank?
      redirect_to employee_masters_path, alert: "Please choose an Excel or CSV file."
      return
    end

    result = import_rows(params[:file])
    redirect_to employee_masters_path, notice: import_success_message(result)
  rescue StandardError => error
    redirect_to employee_masters_path, alert: "Import failed: #{error.message}"
  end

  def sync_logins
    synced_count = EmployeeMaster.where.not(email_id: [nil, ""], employee_code: [nil, ""]).find_each.count do |employee|
      EmployeeLoginProvisioner.provision_for!(employee)
    end

    redirect_to employee_masters_path, notice: "#{synced_count} employee-code logins are ready now."
  rescue StandardError => error
    redirect_to employee_masters_path, alert: "Login sync failed: #{error.message}"
  end

  private

  def set_employee_master
    @employee_master = EmployeeMaster.find(params[:id])
  end

  def employee_delete_blocked_message
    "#{@employee_master.name} is used in approval flow or transaction records. Remove/replace this employee from those records before deleting."
  end

  def selected_ids(param_name)
    Array(params[param_name]).reject(&:blank?)
  end

  def employee_bulk_delete_flash(deleted_count, blocked_names)
    flash_messages = {}
    flash_messages[:notice] = "#{deleted_count} employee(s) deleted successfully." if deleted_count.positive?
    if blocked_names.present?
      examples = blocked_names.first(5).join(", ")
      flash_messages[:alert] = "#{blocked_names.size} employee(s) could not be deleted because they are used in approval flow or transaction records: #{examples}."
    elsif deleted_count.zero?
      flash_messages[:alert] = "No employees were deleted."
    end
    flash_messages
  end

  def employee_master_params
    params.require(:employee_master).permit(
      :stakeholder_category_id, :user_type, :name, :designation, :email_id, :password, :password_confirmation,
      :employee_code,
      :mobile_no, :state_id, :district_id, :block_id, :gram_panchayat, :village, :parent_office, :office,
      :location, :full_address, :pincode
    )
  end

  def import_rows(file)
    extension = File.extname(file.original_filename).downcase
    unless [".csv", ".xls", ".xlsx"].include?(extension)
      raise "Please upload a CSV, XLS, or XLSX file."
    end

    rows = extension == ".csv" ? csv_rows(file) : spreadsheet_rows(file, extension)

    return import_password_rows(rows) if password_update_sheet?(rows)

    imported_count = 0
    password_count = 0
    rows.each do |row|
      next if row.values.all?(&:blank?)

      stakeholder = StakeholderCategory.find_by(name: row["stakeholder"].to_s.strip)
      state = State.find_by(name: row["state"].to_s.strip)
      district = District.find_by(name: row["district"].to_s.strip)
      block = Block.find_by(name: row["block"].to_s.strip)
      employee_code = row["employee_code"].presence || row["employee_id"].presence
      lookup_email = row["email_id"].presence || row["employee_email_id"].presence

      employee = if employee_code.present?
        find_employee_by_import_code(employee_code) || EmployeeMaster.new(employee_code: employee_code.to_s.strip.upcase)
      elsif lookup_email.present?
        EmployeeMaster.find_or_initialize_by(email_id: lookup_email.to_s.strip.downcase)
      else
        EmployeeMaster.find_or_initialize_by(name: row["user_name"].presence || row["employee_name"].to_s.strip)
      end

      employee.assign_attributes(
        stakeholder_category: stakeholder,
        user_type: row["user_type"].presence || "User",
        employee_code: employee_code,
        name: row["user_name"].presence || row["employee_name"],
        designation: row["designation"],
        location: row["employee_location"] || row["location"],
        email_id: lookup_email,
        mobile_no: row["mobile_no"],
        state: state,
        district: district,
        block: block,
        gram_panchayat: row["gram_panchayat"],
        village: row["village"],
        parent_office: row["parent_office"],
        office: row["office"],
        full_address: row["full_address"],
        pincode: row["pincode"]
      )
      password = clean_import_password(row["password"])
      password_confirmation = clean_import_password(row["password_confirmation"]).presence || password
      if password.present?
        validate_import_password_pair!(password, password_confirmation, employee_code.presence || lookup_email.presence || employee.name)
        employee.password = password
        employee.password_confirmation = password_confirmation
        password_count += 1
      end

      employee.save!
      imported_count += 1
    end

    { mode: :employee_import, imported_count: imported_count, password_count: password_count, skipped_count: 0 }
  end

  def import_password_rows(rows)
    updated_count = 0
    skipped_rows = []

    rows.each_with_index do |row, index|
      next if row.values.all?(&:blank?)

      employee_code = row["employee_code"].presence || row["employee_id"].presence
      password = clean_import_password(row["password"])
      password_confirmation = clean_import_password(row["password_confirmation"]).presence || password

      if employee_code.blank? || password.blank?
        skipped_rows << "row #{index + 2}"
        next
      end

      unless import_password_valid?(password, password_confirmation)
        skipped_rows << "#{employee_code.to_s.strip} password"
        next
      end

      employee = find_employee_by_import_code(employee_code)
      if employee.blank? || employee.email_id.blank?
        skipped_rows << employee_code.to_s.strip
        next
      end

      EmployeeLoginProvisioner.provision_for!(
        employee,
        password: password,
        password_confirmation: password_confirmation
      )
      updated_count += 1
    end

    {
      mode: :password_update,
      imported_count: 0,
      password_count: updated_count,
      skipped_count: skipped_rows.size,
      skipped_examples: skipped_rows.first(10)
    }
  end

  def generate_csv(employee_masters)
    headers = [
      "stakeholder",
      "user_type",
      "employee_code",
      "user_name",
      "designation",
      "employee_email_id",
      "mobile_no",
      "state",
      "district",
      "block",
      "gram_panchayat",
      "village",
      "parent_office",
      "office",
      "employee_location",
      "full_address",
      "pincode",
      "login_status"
    ]

    CSV.generate(headers: true) do |csv|
      csv << headers

      employee_masters.each do |employee|
        csv << [
          employee.stakeholder_category&.name,
          employee.user_type,
          employee.employee_code,
          employee.name,
          employee.designation,
          employee.email_id,
          employee.mobile_no,
          employee.state&.name,
          employee.district&.name,
          employee.block&.name,
          employee.gram_panchayat,
          employee.village,
          employee.parent_office,
          employee.office,
          employee.location,
          employee.full_address,
          employee.pincode,
          employee.login_ready? ? "Ready" : "Not Ready"
        ]
      end
    end
  end

  def csv_rows(file)
    CSV.parse(file.read, headers: true).map do |row|
      normalize_row_keys(row.to_h)
    end
  end

  def spreadsheet_rows(file, extension)
    return xls_rows(file) if extension == ".xls"

    require "roo"
    sheet = Roo::Spreadsheet.open(file.path, extension: extension.delete_prefix(".").to_sym)
    header = sheet.row(1).map { |value| normalize_header(value) }

    (2..sheet.last_row).map do |index|
      normalize_row_keys(Hash[header.zip(sheet.row(index))])
    end
  rescue LoadError
    raise "Excel upload requires the 'roo' gem. Run bundle install, or upload a CSV file."
  end

  def xls_rows(file)
    office_binary = %w[soffice libreoffice].find { |binary| system("which", binary, out: File::NULL, err: File::NULL) }
    raise "XLS upload requires LibreOffice. Please upload CSV or XLSX instead." if office_binary.blank?

    Dir.mktmpdir("employee-master-xls") do |dir|
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

      CSV.parse(File.read(converted_path), headers: true).map do |row|
        normalize_row_keys(row.to_h)
      end
    end
  end

  def normalize_row_keys(row)
    row.transform_keys { |key| normalize_header(key) }.reject { |key, _value| key.blank? }
  end

  def normalize_header(header)
    value = header.to_s.strip.downcase.gsub(/\s+/, " ")

    case value
    when "stakeholder" then "stakeholder"
    when "user type", "user_type" then "user_type"
    when "employee code", "employee_code", "employee id", "employee_id", "emp code", "emp_code", "emp id", "emp_id" then "employee_code"
    when "password", "passsword", "passowrd", "passwrod" then "password"
    when "confirm password", "confirm_password", "confirmed password", "password confirmation", "password_confirmation",
         "confrim password", "confirm passsword", "confirm passwowrd", "confirm passwrod" then "password_confirmation"
    when "user name", "user_name" then "user_name"
    when "employee name", "employee_name", "emp name", "emp_name" then "employee_name"
    when "designation" then "designation"
    when "employee location", "employee_location", "location" then "employee_location"
    when "employee email id", "employee_email_id", "email", "email id" then "employee_email_id"
    when "mobile", "mobile no", "mobile_no", "phone" then "mobile_no"
    when "state" then "state"
    when "district" then "district"
    when "block" then "block"
    when "gram panchayat", "gram_panchayat" then "gram_panchayat"
    when "village" then "village"
    when "parent office", "parent_office" then "parent_office"
    when "office" then "office"
    when "full address", "full_address", "address" then "full_address"
    when "pincode", "pin code", "pin" then "pincode"
    else value.tr(" ", "_")
    end
  end

  def password_update_sheet?(rows)
    keys = rows.flat_map(&:keys).compact.uniq
    keys.include?("employee_code") &&
      keys.include?("password") &&
      (keys - %w[employee_code employee_id password password_confirmation]).empty?
  end

  def find_employee_by_import_code(employee_code)
    normalized_code = normalize_import_employee_code(employee_code)
    return if normalized_code.blank?

    EmployeeMaster.find_by("UPPER(TRIM(employee_code)) = ?", normalized_code) ||
      EmployeeMaster.where.not(employee_code: [nil, ""]).find do |employee|
        normalize_import_employee_code(employee.employee_code) == normalized_code
      end
  end

  def normalize_import_employee_code(employee_code)
    employee_code.to_s.strip.upcase.sub(/\A0+(?=\d)/, "")
  end

  def clean_import_password(password)
    password.to_s.strip.sub(/\A['‘’]+/, "")
  end

  def import_password_valid?(password, password_confirmation)
    password == password_confirmation && Devise.password_length.cover?(password.length)
  end

  def validate_import_password_pair!(password, password_confirmation, label)
    return if import_password_valid?(password, password_confirmation)

    raise "Invalid password for #{label}: password and confirmation must match and be #{Devise.password_length.min}-#{Devise.password_length.max} characters."
  end

  def import_success_message(result)
    if result[:mode] == :password_update
      message = "#{result[:password_count]} employee passwords updated successfully."
      if result[:skipped_count].positive?
        message += " #{result[:skipped_count]} rows skipped"
        message += " (#{result[:skipped_examples].join(', ')})" if result[:skipped_examples].present?
        message += "."
      end
      return message
    end

    message = "#{result[:imported_count]} employees imported successfully. Login access was created for employees with employee codes and email IDs."
    message += " #{result[:password_count]} passwords synced from the sheet." if result[:password_count].positive?
    message
  end

  def load_location_collections
    @states = State.order(:name)
    @districts = District.includes(:state).order(:name)
    @blocks = Block.includes(district: :state).order(:name)
  end
end
