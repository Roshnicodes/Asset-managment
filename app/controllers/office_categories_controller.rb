class OfficeCategoriesController < ApplicationController
  before_action :set_office_category, only: %i[ show edit update destroy ]

  # GET /office_categories or /office_categories.json
  def index
    @office_categories, @pagination = paginate_scope(OfficeCategory.ordered)
  end

  def import
    if params[:file].blank?
      redirect_to office_categories_path, alert: "Please choose an Excel or CSV file."
      return
    end

    result = OfficeStructureImporter.call(params[:file])
    redirect_to office_categories_path, notice: office_structure_import_success_message(result)
  rescue StandardError => error
    redirect_to office_categories_path, alert: "Import failed: #{error.message}"
  end

  def destroy_selected
    office_category_ids = selected_ids(:office_category_ids)
    if office_category_ids.blank?
      redirect_to office_categories_path, alert: "Please select at least one office structure to delete.", status: :see_other
      return
    end

    office_categories = OfficeCategory
      .where(id: office_category_ids)
      .includes(:office_category_master, :state, :district, :block, parent: [:state, :district, :block, :office_category_master])

    deleted_count, blocked_names = destroy_selected_records(office_categories) do |office_category|
      office_category.display_name
    end

    redirect_to office_categories_path,
                flash: bulk_delete_flash("office structure", deleted_count, blocked_names),
                status: :see_other
  end

  # GET /office_categories/1 or /office_categories/1.json
  def show
  end

  # GET /office_categories/new
  def new
    @office_category = OfficeCategory.new
    load_form_collections
  end

  # GET /office_categories/1/edit
  def edit
    load_form_collections
  end

  # POST /office_categories or /office_categories.json
  def create
    @office_category = OfficeCategory.new(office_category_params)

    respond_to do |format|
      if @office_category.save
        format.html { redirect_to office_categories_path, notice: "Office structure was successfully created." }
        format.json { render :show, status: :created, location: @office_category }
      else
        load_form_collections
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @office_category.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /office_categories/1 or /office_categories/1.json
  def update
    respond_to do |format|
      if @office_category.update(office_category_params)
        format.html { redirect_to office_categories_path, notice: "Office structure was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @office_category }
      else
        load_form_collections
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @office_category.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /office_categories/1 or /office_categories/1.json
  def destroy
    respond_to do |format|
      if @office_category.destroy
        format.html { redirect_to office_categories_path, notice: "Office structure was successfully deleted.", status: :see_other }
        format.json { head :no_content }
      else
        format.html do
          redirect_to office_categories_path,
                      alert: @office_category.errors.full_messages.to_sentence.presence || "Office structure could not be deleted.",
                      status: :see_other
        end
        format.json { render json: @office_category.errors, status: :unprocessable_entity }
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_office_category
      @office_category = OfficeCategory.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def office_category_params
      params.expect(office_category: [:name, :parent_id, :stakeholder_category_id, :office_category_master_id, :state_id, :district_id, :block_id])
    end

    def load_form_collections
      @stakeholders = StakeholderCategory.order(:name)
      @states = State.order(:name)
      @district_filter_data = District.includes(:state).order(:name).map do |district|
        { id: district.id, name: district.name, state_id: district.state_id }
      end
      @block_filter_data = Block.includes(district: :state).order(:name).map do |block|
        { id: block.id, name: block.name, district_id: block.district_id, state_id: block.district&.state_id }
      end

      category_master_scope = OfficeCategoryMaster.includes(:stakeholder_category).ordered
      if @office_category.stakeholder_category_id.present?
        category_master_scope = category_master_scope.where(stakeholder_category_id: @office_category.stakeholder_category_id)
      end
      @category_master_options = category_master_scope.map do |master|
        [master.name, master.id]
      end

      parent_scope = OfficeCategory.ordered
      parent_scope = parent_scope.where.not(id: @office_category.id) if @office_category.persisted?
      if @office_category.stakeholder_category_id.present?
        parent_scope = parent_scope.where(stakeholder_category_id: @office_category.stakeholder_category_id)
      end
      @parent_category_options = parent_scope.map do |category|
        [category.display_name, category.id]
      end
    end

    def office_structure_import_success_message(result)
      message = "#{result.office_structures_created} office structures imported successfully."
      message += " #{result.office_structures_skipped} duplicates skipped." if result.office_structures_skipped.positive?
      message += " #{result.category_masters_created} category masters created." if result.category_masters_created.positive?

      location_count = result.states_created + result.districts_created + result.blocks_created
      if location_count.positive?
        message += " Locations created: #{result.states_created} states, #{result.districts_created} districts, #{result.blocks_created} blocks."
      end

      if result.rows_skipped.positive?
        message += " #{result.rows_skipped} rows skipped"
        message += " (#{result.skipped_examples.join(', ')})" if result.skipped_examples.present?
        message += "."
      end

      message
    end

    def selected_ids(param_name)
      Array(params[param_name]).reject(&:blank?)
    end

    def destroy_selected_records(records)
      deleted_count = 0
      blocked_names = []

      records.each do |record|
        label = yield(record)
        if record.destroy
          deleted_count += 1
        else
          blocked_names << label
        end
      rescue ActiveRecord::DeleteRestrictionError, ActiveRecord::InvalidForeignKey, ActiveRecord::RecordNotDestroyed
        blocked_names << label
      end

      [deleted_count, blocked_names]
    end

    def bulk_delete_flash(label, deleted_count, blocked_names)
      flash_messages = {}
      flash_messages[:notice] = "#{deleted_count} #{label}(s) deleted successfully." if deleted_count.positive?
      if blocked_names.present?
        examples = blocked_names.first(5).join(", ")
        flash_messages[:alert] = "#{blocked_names.size} #{label}(s) could not be deleted because they are used in other records: #{examples}."
      elsif deleted_count.zero?
        flash_messages[:alert] = "No #{label}s were deleted."
      end
      flash_messages
    end
end
