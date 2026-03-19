class DashboardController < ApplicationController
  def index
    @dashboard_stats = [
      {
        label: "Office Categories",
        value: safe_count(OfficeCategory),
        tone: "teal",
        path: office_categories_path
      },
      {
        label: "Geography Records",
        value: safe_total(State, District, Block),
        tone: "gold",
        path: states_path
      },
      {
        label: "Product Setup",
        value: safe_total(Theme, Product, ProductVariety),
        tone: "emerald",
        path: themes_path
      },
      {
        label: "Vendor Forms",
        value: safe_count(VendorRegistration),
        tone: "slate",
        path: vendor_registrations_path
      }
    ]

    @dashboard_sections = [
      {
        title: "Core Setup",
        description: "Office, stakeholder, registration, service, document, unit, bank, approval, and firm masters.",
        path: office_categories_path,
        cta: "Open Setup"
      },
      {
        title: "LG Mapping",
        description: "Manage states, districts, blocks, FCOs, and TOs for location-based workflows.",
        path: tos_path,
        cta: "Open LG"
      },
      {
        title: "Vendor Registration",
        description: "Track thematic choices, product selection, business details, and form submissions.",
        path: vendor_registrations_path,
        cta: "Open Vendors"
      }
    ]

    @quick_actions = [
      { label: "Add TO", path: new_to_path },
      { label: "Add Product", path: new_product_path },
      { label: "Add Vendor", path: new_vendor_registration_path },
      { label: "View Approvals", path: approval_channels_path }
    ]

    @health_cards = [
      { label: "Approvals", value: safe_count(ApprovalChannel), path: approval_channels_path },
      { label: "Assets", value: safe_count(Asset), path: assets_path },
      { label: "Allocations", value: safe_count(Allocation), path: allocations_path }
    ]
  end

  private

  def safe_count(model)
    model.count
  rescue StandardError
    0
  end

  def safe_total(*models)
    models.sum { |model| safe_count(model) }
  end
end
