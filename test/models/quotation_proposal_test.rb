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
