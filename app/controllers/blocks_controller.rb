class BlocksController < ApplicationController
  before_action :set_block, only: %i[ show edit update destroy ]

  # GET /blocks or /blocks.json
  def index
    @blocks = Block.includes(district: :state).order(:name)
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
    @block.destroy!

    respond_to do |format|
      format.html { redirect_to blocks_path, notice: "Block was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
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
end
