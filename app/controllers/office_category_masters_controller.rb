class OfficeCategoryMastersController < ApplicationController
  before_action :set_office_category_master, only: %i[show edit update destroy]

  def index
    office_category_masters = OfficeCategoryMaster
      .joins(:stakeholder_category)
      .includes(:stakeholder_category)
      .order("stakeholder_categories.name ASC, office_category_masters.name ASC")
    if search_query.present?
      office_category_masters = office_category_masters.where(
        "LOWER(office_category_masters.name) LIKE :query OR LOWER(stakeholder_categories.name) LIKE :query",
        query: search_pattern
      )
    end

    @office_category_masters, @pagination = paginate_scope(office_category_masters)
  end

  def show
    redirect_to office_category_masters_path
  end

  def new
    @office_category_master = OfficeCategoryMaster.new
    load_stakeholders
  end

  def edit
    load_stakeholders
  end

  def create
    @office_category_master = OfficeCategoryMaster.new(office_category_master_params)

    if @office_category_master.save
      redirect_to office_category_masters_path, notice: "Office category master was successfully created."
    else
      load_stakeholders
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @office_category_master.update(office_category_master_params)
      redirect_to office_category_masters_path, notice: "Office category master was successfully updated.", status: :see_other
    else
      load_stakeholders
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @office_category_master.destroy
      redirect_to office_category_masters_path, notice: "Office category master was successfully deleted.", status: :see_other
    else
      redirect_to office_category_masters_path,
                  alert: @office_category_master.errors.full_messages.to_sentence.presence || "Office category master could not be deleted.",
                  status: :see_other
    end
  end

  private

  def set_office_category_master
    @office_category_master = OfficeCategoryMaster.find(params.expect(:id))
  end

  def office_category_master_params
    params.expect(office_category_master: [:stakeholder_category_id, :name])
  end

  def load_stakeholders
    @stakeholders = StakeholderCategory.order(:name)
  end
end
