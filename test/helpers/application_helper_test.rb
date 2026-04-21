require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  tests ApplicationHelper
  self.fixture_table_names = []
  self.fixture_sets = {}
  self.fixture_class_names = {}

  def current_employee_master
    @current_employee_master
  end

  test "navbar logo uses attached stakeholder logo for current employee" do
    stakeholder = StakeholderCategory.create!(name: "PGPL")
    stakeholder.logo_file.attach(
      io: StringIO.new("pgpl-logo"),
      filename: "pgpl.jpeg",
      content_type: "image/jpeg"
    )

    @current_employee_master = EmployeeMaster.new(
      name: "User 2",
      email_id: "user2@example.com",
      user_type: "User",
      stakeholder_category: stakeholder
    )

    assert_match %r{\A/rails/active_storage/blobs/redirect/}, navbar_logo_source
    assert_match %r{/pgpl\.jpeg\z}, navbar_logo_source
    assert_equal "PGPL Logo", navbar_logo_alt
  end
end
