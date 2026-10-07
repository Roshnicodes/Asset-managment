# Role-aware home page: what is waiting on the signed-in user, a summary of
# their own vendor registrations and quotations, recent records and alerts.
# Admins see the whole system; everyone else only their own work.
class DashboardController < ApplicationController
  RECENT_LIMIT = 5

  def index
    @employee = current_employee_master
    @admin = admin_user?
    @greeting = greeting_for(Time.current.in_time_zone("Asia/Kolkata"))
    @months_back = params[:months].to_i == 12 ? 12 : 6
    @month_starts = month_starts(@months_back)
    @month_labels = @month_starts.map { |month| month.strftime("%b") }

    @tasks = build_tasks.select { |task| task[:count].to_i.positive? }
    @quick_actions = build_quick_actions
    @summary_cards = build_summary_cards
    @overview_series = @summary_cards.map { |card| { label: card[:series_label], color: card[:color], values: card[:chart_values] } }
    @status_segments = build_status_segments
    @recent_quotations = quotation_scope.includes(:theme, :user, :approval_request, :committee_steps, :quotation_proposal_items,
                                                  { quotation_proposal_vendors: [:vendor_registration, :committee_member_scores] })
                                        .order(created_at: :desc).limit(RECENT_LIMIT)
    @recent_vendor_registrations = vendor_scope.includes(:approval_request).order(created_at: :desc).limit(RECENT_LIMIT)
    @notifications = current_user.notifications.order(created_at: :desc).limit(RECENT_LIMIT)
    today = Time.current.in_time_zone("Asia/Kolkata").to_date
    @deadlines = quotation_scope.includes(:theme)
                                .where(proposal_end_date: today..(today + 14.days), selected_vendor_registration_id: nil)
                                .order(:proposal_end_date).limit(RECENT_LIMIT)
    @today = today
  end

  # Header search: quotations, vendor registrations and products the user can open.
  def search
    @query = params[:q].to_s.strip
    if @query.length < 2
      @quotations = @vendors = @products = []
      return
    end

    term = "%#{ActiveRecord::Base.sanitize_sql_like(@query.downcase)}%"
    @admin = admin_user?
    @quotations = quotation_scope.includes(:theme).where("LOWER(subject) LIKE ?", term).order(created_at: :desc).limit(20)
    @vendors = vendor_scope.includes(:approval_request)
                           .where("LOWER(vendor_name) LIKE :t OR LOWER(firm_name) LIKE :t OR mobile_no LIKE :t OR LOWER(email) LIKE :t", t: term)
                           .order(created_at: :desc).limit(20)
    @products = can_open?("products") ? Product.where("LOWER(name) LIKE ?", term).order(:name).limit(20) : []
  end

  private

  def greeting_for(time)
    case time.hour
    when 5...12 then "Good morning"
    when 12...17 then "Good afternoon"
    else "Good evening"
    end
  end

  # Records the user is responsible for (all records for an admin).
  def quotation_scope
    @admin ? QuotationProposal.all : QuotationProposal.where(user_id: current_user.id)
  end

  def vendor_scope
    @admin ? VendorRegistration.all : VendorRegistration.where(user_id: current_user.id)
  end

  def quotation_maker?
    @quotation_maker ||= can_open?("quotation_proposal_form") && quotation_proposal_maker?
  end

  def vendor_maker?
    @vendor_maker ||= can_open?("vendor_registration") && vendor_registration_maker?
  end

  def can_open?(identifier)
    helpers.can_view_menu?(identifier)
  end

  # Work waiting on this user; only tasks with a count are shown.
  def build_tasks
    pending_actions = helpers.quotation_pending_actions
    tasks = []

    tasks << task("Vendor registrations to approve", helpers.pending_approvals_count("Vendor Registration"),
                  approval_requests_path(status: "pending", form_name: "Vendor Registration"), :approval, "red")
    tasks << task("Quotations to approve", pending_actions.count { |_id, kind| kind == :approval },
                  list_quotation_proposals_path, :approval, "red")
    tasks << task("Committee scoring pending", pending_actions.count { |_id, kind| kind == :scoring },
                  list_quotation_proposals_path, :document, "amber")
    tasks << task("Quotations returned to you", pending_actions.count { |_id, kind| kind == :returned },
                  quotation_proposals_path, :document, "amber")
    tasks << task("Vendor registrations returned to you", returned_vendor_registrations.count,
                  vendor_registrations_path, :people, "amber")

    if quotation_maker?
      tasks << task("Approved, send to vendors", quotation_scope.joins(:approval_request)
                      .where(approval_requests: { status: "approved" }, sent_to_vendors_at: nil).count,
                    quotation_proposals_path, :document, "teal")
      tasks << task("Quotations not sent for approval", quotation_scope.where.missing(:approval_request)
                      .where(sent_to_vendors_at: nil, thematic_head_requested_at: nil).count,
                    quotation_proposals_path, :document, "slate")
      tasks << task("Purchase orders to create", purchase_orders_to_create.count, quotation_proposals_path, :document, "teal")
      tasks << task("Invoices to review", invoices_to_review.count, quotation_proposals_path, :bank, "teal")
    end

    if vendor_maker?
      tasks << task("Vendor registrations not sent", vendor_scope.where.missing(:approval_request).count,
                    vendor_registrations_path, :people, "slate")
    end

    if finance_queue_access?
      tasks << task("Finance payment queue", finance_queue.count, payment_advice_quotation_proposals_path, :bank, "teal")
    end

    tasks
  end

  def task(label, count, path, icon, tone)
    { label: label, count: count, path: path, icon: icon, tone: tone }
  end

  def returned_vendor_registrations
    VendorRegistration.where(user_id: current_user.id).joins(:approval_request)
                      .where(approval_requests: { status: "returned", return_mode: "employee" })
  end

  def purchase_orders_to_create
    QuotationProposalVendor.where(selected: true, purchase_order_status: [nil, "", "draft"])
                           .where(quotation_proposal_id: quotation_scope.select(:id))
  end

  def invoices_to_review
    QuotationProposalVendorInvoiceRequest.where(status: "uploaded")
                                         .joins(:quotation_proposal_vendor)
                                         .where(quotation_proposal_vendors: { quotation_proposal_id: quotation_scope.select(:id) })
  end

  def finance_queue
    QuotationProposalVendorInvoiceRequest.where.not(pdo_no: [nil, ""]).where.not(rfp_no: [nil, ""])
                                         .where.not(rfp_created_on: nil).where(payment_advice_sent_at: nil)
  end

  def build_quick_actions
    actions = []
    actions << { label: "Request for Proposal", path: new_quotation_proposal_path, icon: :document, tone: "green" } if quotation_maker?
    actions << { label: "Add Vendor", path: new_vendor_registration_path, icon: :people, tone: "blue" } if vendor_maker?
    actions << { label: "Send Registration Link", path: new_vendor_registration_invitation_path, icon: :vendor, tone: "purple" } if vendor_maker?
    actions << { label: "My Approvals", path: approval_requests_path(status: "pending"), icon: :approval, tone: "amber" } if @admin || current_approval_employee_ids.any?
    actions << { label: "Finance Queue", path: payment_advice_quotation_proposals_path, icon: :bank, tone: "teal" } if finance_queue_access?
    actions << { label: "Procurement Settings", path: procurement_settings_path, icon: :key, tone: "slate" } if @admin
    actions << { label: "User Manual", path: user_manual_path, icon: :document, tone: "slate" } if actions.size.odd?
    actions
  end

  def month_starts(count)
    current = Time.current.in_time_zone("Asia/Kolkata").beginning_of_month
    (count - 1).downto(0).map { |back| current - back.months }
  end

  # Monthly counts for the chart and sparklines: [n, n, ...] oldest first.
  def monthly_counts(scope, column)
    from = @month_starts.first
    counts = scope.where(column => from..).group(Arel.sql("date_trunc('month', #{column} AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Kolkata')")).count
    by_month = counts.transform_keys { |key| key.to_date.beginning_of_month }
    @month_starts.map { |month| by_month[month.to_date].to_i }
  end

  # Growth in the last 30 days, in % of what existed before; nil when there
  # was nothing before (shown as "New").
  def growth(scope, column)
    since = 30.days.ago
    recent = scope.where(column => since..).count
    before = scope.where(column => ...since).count
    return 0 if recent.zero?
    return nil if before.zero?

    ((recent * 100.0) / before).round
  end

  def approval_steps_scope
    steps = ApprovalStep.where(status: "approved")
    @admin ? steps : steps.where(employee_master_id: current_approval_employee_ids)
  end

  def build_status_segments
    vendor_statuses = vendor_scope.left_joins(:approval_request).group("approval_requests.status").count
    quotation_statuses = quotation_scope.left_joins(:approval_request).group("approval_requests.status").count
    combined = vendor_statuses.merge(quotation_statuses) { |_status, a, b| a + b }
    [
      { label: "Approved", value: combined["approved"].to_i, color: "#14996b" },
      { label: "In Approval", value: combined["pending"].to_i, color: "#2f74e0" },
      { label: "Returned", value: combined["returned"].to_i, color: "#f39a1e" },
      { label: "Rejected", value: combined["rejected"].to_i, color: "#e04848" },
      { label: "Not Sent", value: combined[nil].to_i, color: "#9b5de5" }
    ]
  end

  def build_summary_cards
    cards = []
    if @admin || vendor_maker? || vendor_scope.exists?
      vendors = vendor_scope.left_joins(:approval_request)
      values = monthly_counts(vendor_scope, "vendor_registrations.created_at")
      cards << {
        title: "Vendor Registrations", icon: :people, tone: "green", color: "#14996b", path: vendor_registrations_path,
        total: vendors.count, trend: growth(vendor_scope, "vendor_registrations.created_at"), chart_values: values, series_label: "Vendor Registrations",
        parts: [
          ["Approved", vendors.where(approval_requests: { status: "approved" }).count, "green"],
          ["In approval", vendors.where(approval_requests: { status: "pending" }).count, "amber"],
          ["Not sent", vendors.where(approval_requests: { id: nil }).count, "red"]
        ]
      }
    end

    if @admin || quotation_maker? || quotation_scope.exists?
      quotations = quotation_scope
      values = monthly_counts(quotation_scope, "quotation_proposals.created_at")
      cards << {
        title: "Quotations", icon: :document, tone: "blue", color: "#2f74e0", path: quotation_proposals_path,
        total: quotations.count, trend: growth(quotation_scope, "quotation_proposals.created_at"), chart_values: values, series_label: "Quotations",
        parts: [
          ["In approval", quotations.joins(:approval_request).where(approval_requests: { status: %w[pending returned] }).count +
                          quotations.where(thematic_head_decision: nil).where.not(thematic_head_requested_at: nil).count, "blue"],
          ["With vendors", quotations.where.not(sent_to_vendors_at: nil).where(selected_vendor_registration_id: nil).count, "purple"],
          ["Not sent", quotations.where.missing(:approval_request).where(sent_to_vendors_at: nil).count, "red"]
        ]
      }

      proposal_vendors = QuotationProposalVendor.where(quotation_proposal_id: quotations.select(:id))
      values = monthly_counts(proposal_vendors.where.not(purchase_order_sent_at: nil), "quotation_proposal_vendors.purchase_order_sent_at")
      cards << {
        title: "Purchase Orders", icon: :cart, tone: "orange", color: "#f39a1e", path: quotation_proposals_path,
        total: proposal_vendors.where(purchase_order_status: %w[sent accepted returned rejected]).count,
        trend: growth(proposal_vendors.where.not(purchase_order_sent_at: nil), "quotation_proposal_vendors.purchase_order_sent_at"), chart_values: values, series_label: "Purchase Orders",
        parts: [
          ["Accepted", proposal_vendors.where(purchase_order_status: "accepted").count, "green"],
          ["Awaiting", proposal_vendors.where(purchase_order_status: "sent").count, "amber"],
          ["To create", purchase_orders_to_create.count, "slate"]
        ]
      }
    end

    if @admin || current_approval_employee_ids.any?
      values = monthly_counts(approval_steps_scope, "approval_steps.actioned_at")
      cards << {
        title: "Approvals", icon: :approval, tone: "red", color: "#e0446a", path: approval_requests_path(status: "pending"),
        total: helpers.pending_approvals_count, trend: growth(approval_steps_scope, "approval_steps.actioned_at"), chart_values: values, series_label: "Approvals",
        total_hint: "pending",
        parts: [
          ["Pending", helpers.pending_approvals_count, "blue"],
          ["Approved", helpers.approved_approvals_count, "purple"]
        ]
      }
    end

    cards
  end

end
