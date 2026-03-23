class EmployeeMastersController < ApplicationController
  require "csv"
  before_action :set_employee_master, only: %i[edit update destroy]

  def index
    @employee_masters = EmployeeMaster.includes(:stakeholder_category).order(:name)
  end

  def new
    @employee_master = EmployeeMaster.new
  end

  def edit
  end

  def create
    @employee_master = EmployeeMaster.new(employee_master_params)

    if @employee_master.save
      redirect_to employee_masters_path, notice: "Employee master created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @employee_master.update(employee_master_params)
      redirect_to employee_masters_path, notice: "Employee master updated successfully."
    else
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
    redirect_to employee_masters_path, notice: "#{imported_count} employees imported successfully."
  rescue StandardError => error
    redirect_to employee_masters_path, alert: "Import failed: #{error.message}"
  end

  private

  def set_employee_master
    @employee_master = EmployeeMaster.find(params[:id])
  end

  def employee_master_params
    params.require(:employee_master).permit(:stakeholder_category_id, :employee_code, :name, :designation, :location, :email_id)
  end

  def import_rows(file)
    extension = File.extname(file.original_filename).downcase
    rows = extension == ".csv" ? csv_rows(file) : spreadsheet_rows(file)

    imported_count = 0
    rows.each do |row|
      next if row.values.all?(&:blank?)

      stakeholder = StakeholderCategory.find_by(name: row["stakeholder"].to_s.strip)
      employee = EmployeeMaster.find_or_initialize_by(employee_code: row["employee_id"].to_s.strip)
      employee.assign_attributes(
        stakeholder_category: stakeholder,
        name: row["employee_name"],
        designation: row["designation"],
        location: row["employee_location"] || row["location"],
        email_id: row["employee_email_id"]
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
    when "employee id", "employee_id", "emp id", "emp_id" then "employee_id"
    when "employee name", "employee_name", "emp name", "emp_name" then "employee_name"
    when "designation" then "designation"
    when "employee location", "employee_location", "location" then "employee_location"
    when "employee email id", "employee_email_id", "email", "email id" then "employee_email_id"
    else value.tr(" ", "_")
    end
  end
end
