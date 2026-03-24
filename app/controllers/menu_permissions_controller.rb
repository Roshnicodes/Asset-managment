class MenuPermissionsController < ApplicationController
  def index
    @stakeholder_categories = StakeholderCategory.order(:name)
    @designations = EmployeeMaster.pluck(:designation).compact.uniq.sort
    
    # We will show the table only when Stakeholder Category and Designation are selected
    if params[:stakeholder_category_id].present? && params[:designation].present?
      @current_stakeholder = StakeholderCategory.find(params[:stakeholder_category_id])
      @current_designation = params[:designation]
      
      # Fetch existing permissions
      @permissions = MenuPermission.where(
        stakeholder_category_id: @current_stakeholder.id,
        designation: @current_designation
      ).pluck(:menu_identifier, :can_view).to_h
    end
  end

  def create
    stakeholder_id = params[:stakeholder_category_id]
    designation = params[:designation]
    menu_ids = params[:menu_ids] || [] # Array of identifiers that should be can_view = true

    # Transactional update
    MenuPermission.transaction do
      # Reset all for this combo
      MenuPermission.where(stakeholder_category_id: stakeholder_id, designation: designation).update_all(can_view: false)
      
      # Set selected ones to true
      menu_ids.each do |m_id|
        perm = MenuPermission.find_or_initialize_by(
          stakeholder_category_id: stakeholder_id,
          designation: designation,
          menu_identifier: m_id
        )
        perm.can_view = true
        perm.save!
      end
    end

    redirect_to menu_permissions_path(stakeholder_category_id: stakeholder_id, designation: designation), 
                notice: "Permissions updated successfully."
  end
end
