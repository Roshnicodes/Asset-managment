class ApprovalRequest < ApplicationRecord
  RETURN_MODES = %w[employee level].freeze
  ReturnTargetOption = Struct.new(
    :value,
    :label,
    :submit_label,
    :remark_label,
    :remark_placeholder,
    keyword_init: true
  )
  TrailStep = Struct.new(
    :level,
    :employee_master,
    :from_user,
    :previous_action,
    :current_action,
    :status,
    :actioned_at,
    :remark,
    keyword_init: true
  ) do
    def action_label
      employee = employee_master
      return "Unassigned (Employee)" unless employee

      "#{employee.name} (#{employee.designation.presence || 'Employee'})"
    end

    def current_action_label
      current_action.presence || "Approval"
    end

    def previous_action_label
      previous_action.presence || "-"
    end

    def proposal_create_step?
      level == 1 && current_action.to_s.strip == "Proposal Create"
    end

    def effective_status
      is_initial_step = level == 1 && (previous_action.to_s.strip == "NA" || previous_action.to_s.strip.blank?) && current_action.to_s.strip == "Proposal Create"
      is_initial_step ? "approved" : status
    end

    def effective_status_label
      return "Returned" if effective_status == "returned"
      return "Rejected" if effective_status == "rejected"

      effective_status.capitalize
    end

    def show_status_in_trail?
      !proposal_create_step?
    end
  end

  belongs_to :approval_channel
  belongs_to :approvable, polymorphic: true
  has_many :approval_steps, -> { order(:level) }, dependent: :destroy

  STATUSES = %w[pending approved returned rejected].freeze

  validates :status, inclusion: { in: STATUSES }
  validates :return_mode, inclusion: { in: RETURN_MODES }, allow_nil: true

  scope :active_workflow, -> { where.not(status: %w[approved rejected]) }

  def self.sync_scope!(scope)
    scope.find_each(&:ensure_channel_steps_synced!)
  end

  def current_step
    approval_steps.find_by(status: "pending")
  end

  def ensure_channel_steps_synced!
    return unless approval_channel.present?

    creator_email = approvable.try(:user).try(:email).to_s.strip.downcase
    steps_by_level = approval_steps.index_by(&:level)
    steps_changed = false

    approval_channel.flow_steps.each_with_index do |channel_step, index|
      level = channel_step.step_number || index + 1
      prev_act = channel_step.previous_action.to_s.strip
      curr_act = channel_step.current_action.to_s.strip
      approver_email = channel_step.to_responsible_user&.email_id.to_s.strip.downcase
      initial_step = index.zero? && (
        ((prev_act == "NA" || prev_act.blank?) && curr_act == "Proposal Create") ||
        (approver_email == creator_email && creator_email.present?)
      )

      target_attributes = {
        employee_master: channel_step.to_responsible_user,
        from_user: channel_step.try(:from_user),
        previous_action: channel_step.previous_action,
        current_action: channel_step.current_action
      }
      target_status = inferred_synced_step_status(level, initial_step: initial_step)
      target_actioned_at = initial_step ? (approval_steps.find_by(level: level)&.actioned_at || created_at || Time.current) : nil

      existing_step = steps_by_level[level]
      if existing_step.present?
        next unless syncable_step?(existing_step)

        sync_updates = target_attributes.dup
        sync_updates[:status] = target_status if existing_step.status != target_status
        sync_updates[:actioned_at] = target_actioned_at if existing_step.actioned_at != target_actioned_at

        if step_needs_update?(existing_step, target_attributes) || sync_updates.keys.any? { |key| ![:employee_master, :from_user, :previous_action, :current_action].include?(key) }
          existing_step.update!(sync_updates)
          steps_changed = true
        end
        next
      end

      next if status.in?(%w[approved rejected])

      approval_steps.create!(
        target_attributes.merge(
          level: level,
          status: target_status,
          actioned_at: target_actioned_at
        )
      )
      steps_changed = true
    end

    approval_steps.reset if steps_changed
  end

  def trail_steps
    synced_steps = approval_steps.index_by(&:level)
    channel_steps = approval_channel&.flow_steps.to_a
    return approval_steps if channel_steps.empty?

    channel_steps.map.with_index do |channel_step, index|
      level = channel_step.step_number || index + 1
      synced_steps[level] || TrailStep.new(
        level: level,
        employee_master: channel_step.to_responsible_user,
        from_user: channel_step.try(:from_user),
        previous_action: channel_step.previous_action,
        current_action: channel_step.current_action,
        status: inferred_trail_status_for(level),
        actioned_at: nil,
        remark: nil
      )
    end
  end

  def first_actionable_step
    approval_steps.detect { |step| !step.proposal_create_step? } || approval_steps.first
  end

  def last_actionable_step
    approval_steps.reject(&:proposal_create_step?).max_by(&:level) || approval_steps.max_by(&:level)
  end

  def next_sequential_step_after(step)
    approval_steps
      .where("level > ?", step.level)
      .order(:level)
      .detect { |candidate| candidate.status != "approved" }
  end

  def pending_step_for(employee)
    approval_steps.find_by!(employee_master: employee, status: "pending")
  end

  def previous_return_target_for(step = current_step)
    return_level_targets_for(step).max_by(&:level)
  end

  def employee_return_pending?
    status == "returned" && return_mode == "employee"
  end

  def level_return_pending?
    status == "pending" && return_mode == "level" && returned_by_level.present? && returned_to_level.present?
  end

  def reference_label
    approvable.try(:display_name) || "#{approvable_type} ##{approvable_id}"
  end

  def current_approver_label
    return "-" unless current_step

    "#{current_step.action_label} - #{current_step.current_action_label}"
  end

  def status_label
    if level_return_pending?
      return "L#{returned_by_level} Return To L#{returned_to_level}"
    end

    if employee_return_pending? && returned_by_level.present?
      return "L#{returned_by_level} Return To Employee"
    end

    return "Returned" if status == "returned"
    return "Rejected" if status == "rejected"

    status.capitalize
  end

  def latest_remark
    approval_steps.where.not(remark: [nil, ""]).order(actioned_at: :desc, updated_at: :desc).pick(:remark)
  end

  def employee_return_step
    return unless employee_return_pending? && returned_by_level.present?

    approval_steps
      .where(level: returned_by_level, status: "returned")
      .order(actioned_at: :desc, updated_at: :desc)
      .first
  end

  def employee_return_actor_label
    step = employee_return_step
    return "-" unless step

    action_name = step.current_action_label
    action_name.present? ? "#{step.employee_master.name} (#{action_name})" : step.employee_master.name
  end

  def employee_return_remark
    employee_return_step&.remark.presence || latest_remark
  end

  def approval_history_label
    trail_steps.map do |step|
      detail = "Step #{step.level} #{step.action_label} [#{step.previous_action_label} -> #{step.current_action_label}]: #{step.effective_status_label}"
      detail = "#{detail} on #{step.actioned_at.strftime('%d-%m-%Y %H:%M')}" if step.actioned_at.present?
      step.remark.present? ? "#{detail} (#{step.remark})" : detail
    end.join(" | ")
  end

  def approve!(employee:, remark: nil)
    step = pending_step_for(employee)
    step.update!(status: "approved", remark: remark, actioned_at: Time.current)

    next_step = next_sequential_step_after(step)
    if next_step
      next_step.update!(status: "pending", actioned_at: nil) unless next_step.status == "pending"
      update!(current_level: next_step.level, status: "pending", return_mode: nil, returned_by_level: nil, returned_to_level: nil)
      NotificationDispatcher.notify_approval_step(self, next_step, previous_step: step)
    else
      update!(current_level: nil, status: "approved", return_mode: nil, returned_by_level: nil, returned_to_level: nil)
      approvable.generate_vendor_qr_tokens! if approvable.is_a?(QuotationProposal)
      NotificationDispatcher.notify_request_completed(self, status: "approved", actor: employee, remark: remark)
    end
  end

  def reject!(employee:, remark:)
    step = pending_step_for(employee)
    step.update!(status: "rejected", remark: remark, actioned_at: Time.current)
    update!(current_level: nil, status: "rejected", return_mode: nil, returned_by_level: nil, returned_to_level: nil)
    NotificationDispatcher.notify_request_completed(self, status: "rejected", actor: employee, remark: remark)
  end

  def return_to_employee!(employee:, remark:)
    step = pending_step_for(employee)
    step.update!(status: "returned", remark: remark, actioned_at: Time.current)
    update!(current_level: nil, status: "returned", return_mode: "employee", returned_by_level: step.level, returned_to_level: nil)
    NotificationDispatcher.notify_request_returned(self, actor: employee, remark: remark)
  end

  def return_to_previous_level!(employee:, remark:)
    step = pending_step_for(employee)
    previous_step = previous_return_target_for(step)
    raise ActiveRecord::RecordNotFound, "No previous approver level found" unless previous_step

    return_to_level!(employee: employee, target_level: previous_step.level, remark: remark)
  end

  def return_to_level!(employee:, target_level:, remark:)
    step = pending_step_for(employee)
    target_level = target_level.to_i
    target_step = return_level_targets_for(step).find { |candidate| candidate.level == target_level }
    raise ActiveRecord::RecordNotFound, "Selected approver level was not found" unless target_step

    transaction do
      step.update!(status: "returned", remark: remark, actioned_at: Time.current)

      approval_steps.where(level: (target_step.level + 1)...step.level).each do |intermediate_step|
        intermediate_step.update!(status: "waiting", remark: nil, actioned_at: nil)
      end

      target_step.update!(status: "pending", remark: nil, actioned_at: nil)
      update!(
        current_level: target_step.level,
        status: "pending",
        return_mode: "level",
        returned_by_level: step.level,
        returned_to_level: target_step.level
      )
      NotificationDispatcher.notify_request_returned_to_step(self, actor: employee, remark: remark, target_step: target_step)
    end
  end

  def resubmit_after_return!
    return unless employee_return_pending?

    transaction do
      approval_steps.order(:level).each do |step|
        reset_attributes = { status: "waiting", actioned_at: nil }

        if step.proposal_create_step?
          reset_attributes[:status] = "approved"
          reset_attributes[:actioned_at] = Time.current
        end

        step.update!(reset_attributes)
      end

      next_pending_step = first_actionable_step

      if next_pending_step.present?
        next_pending_step.update!(status: "pending")
        update!(current_level: next_pending_step.level, status: "pending", return_mode: nil, returned_by_level: nil, returned_to_level: nil)
        NotificationDispatcher.notify_approval_step(self, next_pending_step)
      else
        update!(current_level: nil, status: "approved", return_mode: nil, returned_by_level: nil, returned_to_level: nil)
      end
    end
  end

  def return_target_options_for(step = current_step)
    return [] unless step

    return_level_targets_for(step).map do |candidate|
      ReturnTargetOption.new(
        value: "level:#{candidate.level}",
        label: "L#{candidate.level} - #{candidate.action_label}",
        submit_label: "Return To L#{candidate.level}",
        remark_label: "Return To L#{candidate.level} Remark",
        remark_placeholder: "Return to L#{candidate.level} remark"
      )
    end + [
      ReturnTargetOption.new(
        value: "employee",
        label: "Employee",
        submit_label: "Return To Employee",
        remark_label: "Return To Employee Remark",
        remark_placeholder: "Return to employee remark"
      )
    ]
  end

  def return_target_option_for(value, step = current_step)
    return_target_options_for(step).find { |option| option.value == value.to_s }
  end

  private

  def return_level_targets_for(step = current_step)
    return [] unless step

    approval_steps
      .where("level < ?", step.level)
      .order(:level)
      .reject(&:proposal_create_step?)
  end

  def syncable_step?(step)
    step.status.in?(%w[waiting pending]) && step.actioned_at.blank?
  end

  def step_needs_update?(step, target_attributes)
    step.employee_master_id != target_attributes[:employee_master]&.id ||
      step.from_user_id != target_attributes[:from_user]&.id ||
      step.previous_action != target_attributes[:previous_action] ||
      step.current_action != target_attributes[:current_action]
  end

  def inferred_synced_step_status(level, initial_step:)
    return "approved" if initial_step
    return "returned" if status == "returned" && returned_by_level == level
    return "approved" if current_level.present? && level < current_level
    return "pending" if status == "pending" && current_level.present? && level == current_level
    return "approved" if status == "returned" && returned_by_level.present? && level < returned_by_level

    "waiting"
  end

  def inferred_trail_status_for(level)
    return "approved" if level == 1 && trail_initial_step?
    return "returned" if status == "returned" && returned_by_level == level
    return "waiting" if current_level.blank?
    return "approved" if level < current_level
    return "pending" if status == "pending" && level == current_level
    return "approved" if status == "returned" && returned_by_level.present? && level < returned_by_level

    "waiting"
  end

  def trail_initial_step?
    first_channel_step = approval_channel&.flow_steps&.first
    return false unless first_channel_step

    prev_act = first_channel_step.previous_action.to_s.strip
    curr_act = first_channel_step.current_action.to_s.strip
    creator_email = approvable.try(:user).try(:email).to_s.strip.downcase
    approver_email = first_channel_step.to_responsible_user&.email_id.to_s.strip.downcase

    ((prev_act == "NA" || prev_act.blank?) && curr_act == "Proposal Create") ||
      (creator_email.present? && approver_email == creator_email)
  end
end
