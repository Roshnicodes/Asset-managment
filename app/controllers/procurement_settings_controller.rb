# Admin-only options for the procurement flow.
class ProcurementSettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!

  def show
    @single_vendor_approver = AppSetting.single_vendor_approver_designation
  end

  def update
    approver = params[:single_vendor_approver].to_s
    unless AppSetting::SINGLE_VENDOR_APPROVER_OPTIONS.include?(approver)
      redirect_to procurement_settings_path, alert: "Choose Director or COO."
      return
    end

    AppSetting.set(AppSetting::SINGLE_VENDOR_APPROVER, approver)
    redirect_to procurement_settings_path, notice: "Single-vendor requests will now go to the #{approver}."
  end

  private

  def require_admin!
    redirect_to root_path, alert: "Only an admin can change procurement settings." unless admin_user?
  end
end
