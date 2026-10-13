require "test_helper"

# Every in-app notification is also emailed through krai's generic email page,
# but only once NOTIFICATION_MAIL_RELAY_URL is set.
class NotificationMailRelayTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  self.fixture_table_names = []

  FakeResponse = Struct.new(:code, :body, :message, :success) do
    def is_a?(klass)
      klass == Net::HTTPSuccess ? success : super
    end
  end

  setup do
    @stakeholder = StakeholderCategory.create!(name: "Mail Relay Stakeholder")
    @theme = Theme.create!(name: "Mail Relay Theme", stakeholder_category: @stakeholder)
    @employee = EmployeeMaster.create!(designation: "Officer", employee_code: "NM-1", email_id: "notify.me@example.com",
                                       name: "Notify Person", stakeholder_category: @stakeholder, user_type: "User")
    @user = User.find_by!(email: @employee.email_id)
    @quotation = QuotationProposal.new(subject: "Mail relay quotation subject words", theme: @theme, user: @user,
                                       proposal_end_date: Date.current + 5.days, remark: "R", procurement_amount_bucket: "below_10k")
    @quotation.save!(validate: false)
  end

  test "nothing is queued or sent while the relay address is not set" do
    with_env("NOTIFICATION_MAIL_RELAY_URL" => nil) do
      assert_no_enqueued_jobs(only: NotificationMailJob) { create_notification }
    end
  end

  test "a new notification queues one email when the relay is on" do
    with_env("NOTIFICATION_MAIL_RELAY_URL" => "https://krai.asaindia.org/apurti_nnotify.aspx") do
      assert_enqueued_with(job: NotificationMailJob) { create_notification }
    end
  end

  test "the mail link carries recipient, subject, message and the record link" do
    notification = with_env("NOTIFICATION_MAIL_RELAY_URL" => nil) { create_notification }
    called = nil
    fake = ->(uri) { called = uri; FakeResponse.new("200", "Email successfully bhej diya gaya", "OK", true) }

    with_env("NOTIFICATION_MAIL_RELAY_URL" => "https://krai.asaindia.org/apurti_nnotify.aspx", "NOTIFICATION_MAIL_APP_URL" => "https://apurti.asaindia.org") do
      PaymentAdviceMailRelay.stub(:get, fake) { assert NotificationMailRelay.deliver!(notification) }
    end

    assert_equal "/apurti_nnotify.aspx", called.path
    query = URI.decode_www_form(called.query).to_h
    assert_equal NotificationMailRelay::FIELDS, query.keys
    assert_equal "notify.me@example.com", query["to_email"]
    assert_equal "Notify Person", query["to_name"]
    assert_equal "Quotation Proposal - L1 Approval", query["subject"]
    assert_equal "Waiting for your action.", query["message"]
    assert_equal "https://apurti.asaindia.org/quotation_proposals/#{@quotation.id}", query["link"]
  end

  test "a failing mail service never breaks the job" do
    notification = with_env("NOTIFICATION_MAIL_RELAY_URL" => nil) { create_notification }
    fake = ->(_uri) { FakeResponse.new("404", "The resource cannot be found.", "Not Found", false) }

    with_env("NOTIFICATION_MAIL_RELAY_URL" => "https://krai.asaindia.org/apurti_nnotify.aspx") do
      PaymentAdviceMailRelay.stub(:get, fake) do
        assert_nothing_raised { NotificationMailJob.perform_now(notification.id) }
      end
    end
  end

  test "reminder mails are sent at once inside the reminder job" do
    sent = []
    fake = ->(uri) { sent << uri; FakeResponse.new("200", "OK", "OK", true) }

    with_env("NOTIFICATION_MAIL_RELAY_URL" => "https://krai.asaindia.org/apurti_nnotify.aspx") do
      PaymentAdviceMailRelay.stub(:get, fake) do
        NotificationMailJob.inline { create_notification }
      end
    end
    assert_equal 1, sent.size
  end

  test "all kinds go to krai's one Apurti page unless a kind has its own" do
    with_env("NOTIFICATION_MAIL_RELAY_URL" => "https://krai.asaindia.org/") do
      assert_equal "https://krai.asaindia.org/apurti_nnotify.aspx", NotificationMailRelay.page_url("approval_pending")
      assert_equal "https://krai.asaindia.org/apurti_nnotify.aspx", NotificationMailRelay.page_url("payment_recorded")
      assert_equal "https://krai.asaindia.org/apurti_nnotify.aspx", NotificationMailRelay.page_url(nil)
    end
    with_env("NOTIFICATION_MAIL_RELAY_URL" => "https://krai.asaindia.org", "NOTIFICATION_MAIL_PAGE_APPROVAL_PENDING" => "nApprovalPending.aspx") do
      assert_equal "https://krai.asaindia.org/nApprovalPending.aspx", NotificationMailRelay.page_url("approval_pending")
    end
    with_env("NOTIFICATION_MAIL_RELAY_URL" => "https://krai.asaindia.org/apurti_nnotify.aspx") do
      assert_equal "https://krai.asaindia.org/apurti_nnotify.aspx", NotificationMailRelay.page_url("invoice_accepted")
    end
  end

  test "every dispatcher notification has a known kind" do
    source = Rails.root.join("app/services/notification_dispatcher.rb").read
    kinds = source.scan(/mail_kind: "([a-z_]+)"/).flatten + %w[approval_approved approval_rejected]
    assert_equal source.scan("Notification.create!").size, source.scan("mail_kind:").size
    assert_empty kinds.uniq - NotificationMailRelay::KINDS
  end

  test "a kind given its own page is sent there" do
    called = nil
    fake = ->(uri) { called = uri; FakeResponse.new("200", "OK", "OK", true) }

    with_env("NOTIFICATION_MAIL_RELAY_URL" => "https://krai.asaindia.org/", "NOTIFICATION_MAIL_PAGE_COMMITTEE_RETURNED" => "ncommittee.aspx") do
      PaymentAdviceMailRelay.stub(:get, fake) do
        NotificationMailJob.inline { create_notification(mail_kind: "committee_returned") }
      end
    end
    assert_equal "/ncommittee.aspx", called.path
  end

  private

  def create_notification(mail_kind: nil)
    Notification.create!(user: @user, notifiable: @quotation, title: "Quotation Proposal - L1 Approval", message: "Waiting for your action.", mail_kind: mail_kind)
  end

  def with_env(values)
    previous = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
