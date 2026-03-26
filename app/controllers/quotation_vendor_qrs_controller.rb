class QuotationVendorQrsController < ApplicationController
  skip_before_action :authenticate_user!
  layout "public_qr"

  def show
    @quotation_proposal_vendor = QuotationProposalVendor
      .includes(quotation_proposal: [:theme, { quotation_proposal_items: :unit }], vendor_registration: [])
      .find_by!(qr_token: params[:token])

    @quotation_proposal = @quotation_proposal_vendor.quotation_proposal
    @vendor_registration = @quotation_proposal_vendor.vendor_registration
    @stakeholder_category = @quotation_proposal.theme&.stakeholder_category
  end
end
