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
