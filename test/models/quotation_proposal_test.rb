require "test_helper"
require "ostruct"

class QuotationProposalTest < ActiveSupport::TestCase
  DispatchStub = Struct.new(
    :vendor_name,
    :mobile_no,
    :quotation_proposal_vendor,
    :quotation_proposal_id,
    :sent_at,
    :status,
    :updated_attrs,
    keyword_init: true
  ) do
    def update!(attrs)
      self.updated_attrs = attrs
      self.sent_at = attrs[:sent_at] if attrs.key?(:sent_at)
      self.status = attrs[:status] if attrs.key?(:status)
      true
    end
  end

  ProposalVendorStub = Struct.new(:dispatch, keyword_init: true) do
    def dispatch_record!
      dispatch
    end
  end

  VendorCollectionStub = Struct.new(:vendors, keyword_init: true) do
    include Enumerable

    def includes(*)
      self
    end

    def each(&block)
      vendors.each(&block)
    end

    def find_each(&block)
      vendors.each(&block)
    end
  end

  RankedVendorStub = Struct.new(
    :id,
    :rank_position,
    :selected,
    :vendor_registration,
    :response_status,
    :committee_score_total,
    :score_count,
    :grand_total_amount,
    :total_quoted_amount,
    keyword_init: true
  ) do
    def comparable?
      response_submitted?
    end

    def response_submitted?
      response_status == "responded"
    end

    def committee_score_value
      committee_score_total
    end

    def committee_score_count
      score_count
    end

    def selected?
      selected
    end

    def update!(attrs)
      self.selected = attrs[:selected] if attrs.key?(:selected)
      true
    end

    def update_column(attribute, value)
      public_send("#{attribute}=", value)
      true
    end
  end

  RankedVendorCollectionStub = Struct.new(:vendors, keyword_init: true) do
    include Enumerable

    def includes(*)
      self
    end

    def responded
      self.class.new(vendors: vendors.select(&:response_submitted?))
    end

    def each(&block)
      vendors.each(&block)
    end

    def to_a
      vendors
    end

    def find_by(filters)
      vendors.find do |vendor|
        filters.all? { |attribute, value| vendor.public_send(attribute) == value }
      end
    end

    def update_all(attrs)
      vendors.each do |vendor|
        attrs.each { |attribute, value| vendor.public_send("#{attribute}=", value) }
      end
      vendors.size
    end
  end

  test "send_to_vendors marks the proposal sent only after sms delivery succeeds" do
    dispatch = DispatchStub.new(
      vendor_name: "G.TECH",
      mobile_no: "9876543210",
      quotation_proposal_id: 123,
      quotation_proposal_vendor: OpenStruct.new(qr_token: "secure-token"),
      status: "pending"
    )
    proposal, updated_calls, refreshed = build_stubbed_proposal(dispatches: [dispatch])
    sent_dispatches = []

    QuotationVendorSmsGateway.stub(:send_vendor_link, ->(passed_dispatch) { sent_dispatches << passed_dispatch; true }) do
      proposal.send_to_vendors!
    end

    assert_equal [dispatch], sent_dispatches
    assert_equal "sent", dispatch.status
    assert dispatch.sent_at.present?
    assert_equal false, dispatch.updated_attrs[:access_granted]
    assert updated_calls.first[:sent_to_vendors_at].present?
    assert_equal true, refreshed.call
  end

  test "send_to_vendors raises a clear error when the vendor mobile number is missing" do
    dispatch = DispatchStub.new(
      vendor_name: "G.TECH",
      mobile_no: " ",
      quotation_proposal_id: 123,
      quotation_proposal_vendor: OpenStruct.new(qr_token: "secure-token"),
      status: "pending"
    )
    proposal, updated_calls, refreshed = build_stubbed_proposal(dispatches: [dispatch])

    QuotationVendorSmsGateway.stub(:send_vendor_link, ->(_passed_dispatch) { raise "SMS gateway should not be called" }) do
      error = assert_raises(QuotationProposal::VendorDispatchError) { proposal.send_to_vendors! }
      assert_equal "G.TECH does not have a registered mobile number.", error.message
    end

    assert_empty updated_calls
    assert_nil dispatch.updated_attrs
    assert_equal false, refreshed.call
  end

  test "send_to_vendors raises when the sms gateway reports failure" do
    dispatch = DispatchStub.new(
      vendor_name: "G.TECH",
      mobile_no: "9876543210",
      quotation_proposal_id: 123,
      quotation_proposal_vendor: OpenStruct.new(qr_token: "secure-token"),
      status: "pending"
    )
    proposal, updated_calls, refreshed = build_stubbed_proposal(dispatches: [dispatch])

    QuotationVendorSmsGateway.stub(:send_vendor_link, ->(_passed_dispatch) { false }) do
      error = assert_raises(QuotationProposal::VendorDispatchError) { proposal.send_to_vendors! }
      assert_equal "SMS could not be sent to G.TECH on 9876543210. Please verify the SMS setup and try again.", error.message
    end

    assert_empty updated_calls
    assert_nil dispatch.updated_attrs
    assert_equal false, refreshed.call
  end

  test "selected vendors must match quotation stakeholder" do
    proposal = QuotationProposal.new
    vendor = OpenStruct.new(
      stakeholder_category_id: 2,
      display_name: "Mismatch Vendor"
    )

    proposal.define_singleton_method(:stakeholder_category_id) { 1 }
    proposal.define_singleton_method(:vendor_registrations) { [vendor] }

    proposal.send(:selected_vendors_must_match_stakeholder)

    assert_includes(
      proposal.errors[:base],
      "Selected vendors must belong to the same stakeholder as the quotation theme. Mismatch: Mismatch Vendor"
    )
  end

  test "committee requires l1 l2 and l3 members" do
    proposal = QuotationProposal.new
    proposal.define_singleton_method(:committee_steps) do
      [
        OpenStruct.new(level: 1, employee_master_id: 11, marked_for_destruction?: false),
        OpenStruct.new(level: 2, employee_master_id: nil, marked_for_destruction?: false),
        OpenStruct.new(level: 3, employee_master_id: 13, marked_for_destruction?: false)
      ]
    end

    proposal.send(:must_have_all_committee_levels)

    assert_includes proposal.errors[:base], "L2 committee member mandatory hai."
  end

  test "committee allows sequential l1 l2 and l3 members" do
    proposal = QuotationProposal.new
    proposal.define_singleton_method(:committee_steps) do
      [
        OpenStruct.new(level: 1, employee_master_id: 11, marked_for_destruction?: false),
        OpenStruct.new(level: 2, employee_master_id: 12, marked_for_destruction?: false),
        OpenStruct.new(level: 3, employee_master_id: 13, marked_for_destruction?: false)
      ]
    end

    proposal.send(:must_have_all_committee_levels)

    assert_empty proposal.errors[:base]
  end

  test "maker cannot be included in committee members" do
    maker_employee = OpenStruct.new(id: 11)
    maker_user = OpenStruct.new(employee_master: maker_employee)
    proposal = QuotationProposal.new
    proposal.user = maker_user
    proposal.define_singleton_method(:committee_steps) do
      [
        OpenStruct.new(level: 1, employee_master_id: 11, marked_for_destruction?: false),
        OpenStruct.new(level: 2, employee_master_id: 12, marked_for_destruction?: false),
        OpenStruct.new(level: 3, employee_master_id: 13, marked_for_destruction?: false)
      ]
    end

    proposal.send(:maker_cannot_be_committee_member)

    assert_includes proposal.errors[:base], "Maker cannot be part of the approval committee."
  end

  test "committee members must be unique" do
    proposal = QuotationProposal.new
    proposal.define_singleton_method(:committee_steps) do
      [
        OpenStruct.new(level: 1, employee_master_id: 21, marked_for_destruction?: false),
        OpenStruct.new(level: 2, employee_master_id: 21, marked_for_destruction?: false),
        OpenStruct.new(level: 3, employee_master_id: 23, marked_for_destruction?: false)
      ]
    end

    proposal.send(:committee_members_must_be_unique)

    assert_includes proposal.errors[:base], "Committee members must be unique."
  end

  test "committee scoring is complete only when every responded vendor has all committee scores" do
    proposal = QuotationProposal.new
    proposal.define_singleton_method(:committee_steps) do
      [OpenStruct.new, OpenStruct.new, OpenStruct.new]
    end

    vendor_one = RankedVendorStub.new(id: 1, response_status: "responded", score_count: 3)
    vendor_two = RankedVendorStub.new(id: 2, response_status: "responded", score_count: 2)
    vendor_collection = RankedVendorCollectionStub.new(vendors: [vendor_one, vendor_two])
    proposal.define_singleton_method(:quotation_proposal_vendors) { vendor_collection }

    assert_equal false, proposal.committee_scoring_complete?

    vendor_two.score_count = 3

    assert_equal true, proposal.committee_scoring_complete?
  end

  test "sync_vendor_rankings_and_selection waits for all committee scores before selecting a vendor" do
    proposal = QuotationProposal.new
    proposal.define_singleton_method(:committee_steps) do
      [OpenStruct.new, OpenStruct.new, OpenStruct.new]
    end

    vendor_one = RankedVendorStub.new(
      id: 1,
      response_status: "responded",
      committee_score_total: 14,
      score_count: 3,
      grand_total_amount: 206000,
      total_quoted_amount: 200000,
      vendor_registration: VendorRegistration.new(id: 101),
      selected: false
    )
    vendor_two = RankedVendorStub.new(
      id: 2,
      response_status: "responded",
      committee_score_total: 12,
      score_count: 2,
      grand_total_amount: 315000,
      total_quoted_amount: 300000,
      vendor_registration: VendorRegistration.new(id: 102),
      selected: true
    )
    vendor_collection = RankedVendorCollectionStub.new(vendors: [vendor_one, vendor_two])
    refreshed = false

    proposal.define_singleton_method(:quotation_proposal_vendors) { vendor_collection }
    proposal.define_singleton_method(:update!) do |attrs|
      self.selected_vendor_registration_id = attrs[:selected_vendor_registration]&.id if attrs.key?(:selected_vendor_registration)
      true
    end
    proposal.define_singleton_method(:refresh_response_status!) { refreshed = true }

    proposal.sync_vendor_rankings_and_selection!

    assert_equal 1, vendor_one.rank_position
    assert_equal 2, vendor_two.rank_position
    assert_equal false, vendor_one.selected?
    assert_equal false, vendor_two.selected?
    assert_nil proposal.selected_vendor_registration_id
    assert_equal true, refreshed
  end

  test "sync_vendor_rankings_and_selection selects the top ranked vendor after full committee scoring" do
    proposal = QuotationProposal.new
    proposal.define_singleton_method(:committee_steps) do
      [OpenStruct.new, OpenStruct.new, OpenStruct.new]
    end

    vendor_one = RankedVendorStub.new(
      id: 1,
      response_status: "responded",
      committee_score_total: 14,
      score_count: 3,
      grand_total_amount: 206000,
      total_quoted_amount: 200000,
      vendor_registration: VendorRegistration.new(id: 101),
      selected: false
    )
    vendor_two = RankedVendorStub.new(
      id: 2,
      response_status: "responded",
      committee_score_total: 12,
      score_count: 3,
      grand_total_amount: 315000,
      total_quoted_amount: 300000,
      vendor_registration: VendorRegistration.new(id: 102),
      selected: false
    )
    vendor_collection = RankedVendorCollectionStub.new(vendors: [vendor_one, vendor_two])
    refreshed = false

    proposal.define_singleton_method(:quotation_proposal_vendors) { vendor_collection }
    proposal.define_singleton_method(:update!) do |attrs|
      self.selected_vendor_registration_id = attrs[:selected_vendor_registration]&.id if attrs.key?(:selected_vendor_registration)
      true
    end
    proposal.define_singleton_method(:refresh_response_status!) { refreshed = true }

    proposal.sync_vendor_rankings_and_selection!

    assert_equal 1, vendor_one.rank_position
    assert_equal 2, vendor_two.rank_position
    assert_equal true, vendor_one.selected?
    assert_equal false, vendor_two.selected?
    assert_equal 101, proposal.selected_vendor_registration_id
    assert_equal true, refreshed
  end

  private

  def build_stubbed_proposal(dispatches:)
    updated_calls = []
    refreshed = false

    proposal = QuotationProposal.new
    vendor_collection = VendorCollectionStub.new(
      vendors: dispatches.map { |dispatch| ProposalVendorStub.new(dispatch: dispatch) }
    )

    proposal.define_singleton_method(:generate_vendor_qr_tokens!) { true }
    proposal.define_singleton_method(:quotation_proposal_vendors) { vendor_collection }
    proposal.define_singleton_method(:update!) do |attrs|
      updated_calls << attrs
      true
    end
    proposal.define_singleton_method(:refresh_response_status!) do
      refreshed = true
    end

    [proposal, updated_calls, -> { refreshed }]
  end
end
