require "test_helper"

# The dashboard shows each user their own work: what is waiting on them,
# summaries of their records and quick actions they are allowed to use.
class DashboardTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  self.fixture_table_names = []

  setup do
    @stakeholder_category = StakeholderCategory.create!(name: "Dashboard Stakeholder")
    @theme = Theme.create!(name: "Dashboard Theme", stakeholder_category: @stakeholder_category)
  end

  test "a user with no work sees an empty task list and no maker actions" do
    employee = create_employee("Dash Plain", "dash.plain@example.com", "DASH-PLAIN")
    sign_in User.find_by!(email: employee.email_id)

    get root_url

    assert_response :success
    assert_select ".dash-user strong", text: /Dash/
    assert_select ".dash-action-strip--done", text: /All caught up/
    assert_select "a.dash-quick__tile", text: "Request for Proposal", count: 0
    assert_select "a.dash-quick__tile", text: "Procurement Settings", count: 0
  end

  test "an admin sees setup actions" do
    admin = create_employee("Dash Admin", "dash.admin@example.com", "DASH-ADMIN", designation: "Admin", user_type: "Admin")
    user = User.find_by!(email: admin.email_id)
    user.update_columns(role: "admin")
    sign_in user

    get root_url

    assert_response :success
    assert_select "a.dash-quick__tile", text: "Procurement Settings"
    assert_select "a.dash-quick__tile", text: "My Approvals"
  end

  test "a maker sees their quotation that still has to be sent for approval" do
    maker = create_employee("Dash Maker", "dash.maker@example.com", "DASH-MAKER", designation: "Procurement Maker")
    %w[quotation_proposal_form quotation_proposal_list].each do |menu|
      MenuPermission.create!(stakeholder_category: @stakeholder_category, designation: "Procurement Maker", menu_identifier: menu, can_view: true)
    end
    channel = ApprovalChannel.new(approval_type: "Sequential", form_name: "Quotation Request", stakeholder_category: @stakeholder_category, theme: @theme)
    channel.approval_channel_steps.build(current_action: "Proposal Create", previous_action: "NA", step_number: 1, to_responsible_user: maker)
    channel.save!
    user = User.find_by!(email: maker.email_id)
    quotation = QuotationProposal.new(subject: "Dashboard test quotation", theme: @theme, user: user, proposal_end_date: Date.current + 5.days,
                                      remark: "Remark", procurement_amount_bucket: "below_10k")
    quotation.save!(validate: false)
    sign_in user

    get root_url

    assert_response :success
    assert_select "a.dash-quick__tile", text: "Request for Proposal"
    assert_select ".dash-task-chip", text: /Quotations not sent for approval/
    assert_select ".dash-table a", text: "Dashboard test quotation"
    assert_select ".dash-kpi", minimum: 1
    assert_select "svg.dash-chart"

    get app_search_url(q: "dashboard test")
    assert_response :success
    assert_select ".dash-notes strong", text: /Dashboard test quotation/
  end

  private

  def create_employee(name, email, code, designation: "Officer", user_type: "User")
    EmployeeMaster.create!(designation: designation, employee_code: code, email_id: email, name: name,
                           stakeholder_category: @stakeholder_category, user_type: user_type)
  end
end
