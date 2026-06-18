class BlocksController < ApplicationController
  before_action :set_block, only: %i[ show edit update destroy ]

  # GET /blocks or /blocks.json
  def index
    @blocks = Block.includes(district: :state).order(:name)
  end

  def import
    if params[:file].blank?
      redirect_to blocks_path, alert: "Please choose an Excel or CSV file."
      return
    end

    result = LgLocationImporter.call(params[:file])
    flash[:notice] = lg_import_success_message(result) if lg_import_created_count(result).positive?
    flash[:alert] = lg_import_error_message(result) if result.rows_skipped.positive?
    flash[:alert] ||= "No rows were imported. Please check the uploaded file data." if lg_import_created_count(result).zero?
    redirect_to blocks_path
  rescue StandardError => error
    redirect_to blocks_path, alert: "Import failed: #{error.message}"
  end

  def destroy_selected
    block_ids = selected_ids(:block_ids)
    if block_ids.blank?
      redirect_to blocks_path, alert: "Please select at least one block to delete.", status: :see_other
      return
    end

    deleted_count, blocked_names = destroy_selected_records(Block.where(id: block_ids).includes(district: :state)) do |block|
      [block.name, block.district&.name, block.district&.state&.name].compact.join(" / ")
    end

    redirect_to blocks_path,
                flash: bulk_delete_flash("block", deleted_count, blocked_names),
                status: :see_other
  end

  # GET /blocks/1 or /blocks/1.json
  def show
  end

  # GET /blocks/new
  def new
    @block = Block.new
    load_districts
  end

  # GET /blocks/1/edit
  def edit
    load_districts
  end

  # POST /blocks or /blocks.json
  def create
    @block = Block.new(block_params)

    respond_to do |format|
      if @block.save
        format.html { redirect_to blocks_path, notice: "Block was successfully created." }
        format.json { render :show, status: :created, location: @block }
      else
        load_districts
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @block.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /blocks/1 or /blocks/1.json
  def update
    respond_to do |format|
      if @block.update(block_params)
        format.html { redirect_to blocks_path, notice: "Block was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @block }
      else
        load_districts
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @block.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /blocks/1 or /blocks/1.json
  def destroy
    respond_to do |format|
      if @block.destroy
        format.html { redirect_to blocks_path, notice: "Block was successfully destroyed.", status: :see_other }
        format.json { head :no_content }
      else
        format.html { redirect_to blocks_path, alert: block_destroy_error_message, status: :see_other }
        format.json { render json: @block.errors, status: :unprocessable_entity }
      end
    end
  rescue ActiveRecord::InvalidForeignKey
    redirect_to blocks_path, alert: "Cannot delete this block because it is already used in other records.", status: :see_other
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_block
      @block = Block.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def block_params
      params.expect(block: [ :name, :district_id ])
    end

    def load_districts
      @districts = District.includes(:state).order(:name)
    end

    def block_destroy_error_message
      @block.errors.full_messages.to_sentence.presence ||
        "Cannot delete this block because it is already used in other records."
    end

    def lg_import_success_message(result)
      "#{result.states_created} states, #{result.districts_created} districts, and #{result.blocks_created} blocks imported successfully."
    end

    def lg_import_error_message(result)
      message = "#{result.rows_skipped} row(s) could not be imported."
      message += " #{result.skipped_examples.join(', ')}." if result.skipped_examples.present?
      message
    end

    def lg_import_created_count(result)
      result.states_created + result.districts_created + result.blocks_created
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
