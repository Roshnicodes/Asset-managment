class EmployeeMastersController < ApplicationController
  require "csv"
  before_action :set_employee_master, only: %i[edit update destroy]

  def index
    @employee_masters = EmployeeMaster.includes(:stakeholder_category).order(:name)
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
      redirect_to employee_masters_path, notice: "Employee master created successfully. Login access is ready for this employee."
    else
      load_location_collections
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @employee_master.update(employee_master_params)
      redirect_to employee_masters_path, notice: "Employee master updated successfully. Login access has been synced."
    else
      load_location_collections
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @employee_master.destroy!
    redirect_to employee_masters_path, notice: "Employee master deleted successfully.", status: :see_other
  end

  def import
    if params[:file].blank?
      redirect_to employee_masters_path, alert: "Please choose an Excel or CSV file."
      return
    end

    imported_count = import_rows(params[:file])
    redirect_to employee_masters_path, notice: "#{imported_count} employees imported successfully. Login access was created for employees with email IDs."
  rescue StandardError => error
    redirect_to employee_masters_path, alert: "Import failed: #{error.message}"
  end

  def sync_logins
    synced_count = EmployeeMaster.where.not(email_id: [nil, ""]).find_each.count do |employee|
      EmployeeLoginProvisioner.provision_for!(employee)
    end

    redirect_to employee_masters_path, notice: "#{synced_count} employee logins are ready now."
  rescue StandardError => error
    redirect_to employee_masters_path, alert: "Login sync failed: #{error.message}"
  end

  private

  def set_employee_master
    @employee_master = EmployeeMaster.find(params[:id])
  end

  def employee_master_params
    params.require(:employee_master).permit(
      :stakeholder_category_id, :user_type, :name, :designation, :email_id, :password, :password_confirmation,
      :mobile_no, :state_id, :district_id, :block_id, :gram_panchayat, :village, :parent_office, :office,
      :location, :full_address, :pincode
    )
  end

  def import_rows(file)
    extension = File.extname(file.original_filename).downcase
    rows = extension == ".csv" ? csv_rows(file) : spreadsheet_rows(file)

    imported_count = 0
    rows.each do |row|
      next if row.values.all?(&:blank?)

      stakeholder = StakeholderCategory.find_by(name: row["stakeholder"].to_s.strip)
      state = State.find_by(name: row["state"].to_s.strip)
      district = District.find_by(name: row["district"].to_s.strip)
      block = Block.find_by(name: row["block"].to_s.strip)
      lookup_email = row["email_id"].presence || row["employee_email_id"].presence

      employee = if lookup_email.present?
        EmployeeMaster.find_or_initialize_by(email_id: lookup_email.to_s.strip)
      elsif row["employee_id"].present?
        EmployeeMaster.find_or_initialize_by(employee_code: row["employee_id"].to_s.strip)
      else
        EmployeeMaster.find_or_initialize_by(name: row["user_name"].presence || row["employee_name"].to_s.strip)
      end

      employee.assign_attributes(
        stakeholder_category: stakeholder,
        user_type: row["user_type"].presence || "User",
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
      employee.save!
      imported_count += 1
    end

    imported_count
  end

  def csv_rows(file)
    CSV.parse(file.read, headers: true).map do |row|
      normalize_row_keys(row.to_h)
    end
  end

  def spreadsheet_rows(file)
    require "roo"
    sheet = Roo::Spreadsheet.open(file.path)
    header = sheet.row(1).map { |value| normalize_header(value) }

    (2..sheet.last_row).map do |index|
      normalize_row_keys(Hash[header.zip(sheet.row(index))])
    end
  rescue LoadError
    raise "Excel upload requires the 'roo' gem. Run bundle install, or upload a CSV file."
  end

  def normalize_row_keys(row)
    row.transform_keys { |key| normalize_header(key) }
  end

  def normalize_header(header)
    value = header.to_s.strip.downcase.gsub(/\s+/, " ")

    case value
    when "stakeholder" then "stakeholder"
    when "user type", "user_type" then "user_type"
    when "employee id", "employee_id", "emp id", "emp_id" then "employee_id"
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

  def load_location_collections
    @states = State.order(:name)
    @districts = District.includes(:state).order(:name)
    @blocks = Block.includes(district: :state).order(:name)
  end
end
