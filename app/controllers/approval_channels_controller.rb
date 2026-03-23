class ApprovalChannelsController < ApplicationController
  before_action :set_approval_channel, only: %i[ show edit update destroy ]

  # GET /approval_channels or /approval_channels.json
  def index
    @approval_channels = ApprovalChannel.order(:form_name)
  end

  # GET /approval_channels/1 or /approval_channels/1.json
  def show
  end

  # GET /approval_channels/new
  def new
    @approval_channel = ApprovalChannel.new
    load_select_options
  end

  # GET /approval_channels/1/edit
  def edit
    load_select_options
  end

  # POST /approval_channels or /approval_channels.json
  def create
    @approval_channel = ApprovalChannel.new(approval_channel_params)

    respond_to do |format|
      if @approval_channel.save
        format.html { redirect_to approval_channels_path, notice: "Approval channel was successfully created." }
        format.json { render :show, status: :created, location: @approval_channel }
      else
        load_select_options
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @approval_channel.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /approval_channels/1 or /approval_channels/1.json
  def update
    respond_to do |format|
      if @approval_channel.update(approval_channel_params)
        format.html { redirect_to approval_channels_path, notice: "Approval channel was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @approval_channel }
      else
        load_select_options
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @approval_channel.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /approval_channels/1 or /approval_channels/1.json
  def destroy
    @approval_channel.destroy!

    respond_to do |format|
      format.html { redirect_to approval_channels_path, notice: "Approval channel was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_approval_channel
      @approval_channel = ApprovalChannel.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def approval_channel_params
      params.expect(approval_channel: [ :form_name, :approval_type, :level_1_approver, :level_2_approver, :level_3_approver, :stakeholder_category_id ])
    end

    def load_select_options
      @form_names = ApprovalChannel::FORM_NAMES
      @approval_types = ApprovalChannel::APPROVAL_TYPES
    end
end
