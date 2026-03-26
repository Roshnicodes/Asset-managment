class MenuPermission < ApplicationRecord
  belongs_to :stakeholder_category

  validates :designation, :menu_identifier, presence: true
  validates :menu_identifier, uniqueness: { scope: [:stakeholder_category_id, :designation] }

  # Defined menus and submenus based on the sidebar and user requirement
  # format: 'Menu Label' => 'identifier'
  SIDEBAR_MENUS = {
    "Dashboard" => "dashboard",
    "Role Access Control" => "rbac_master",
    "Office Category" => {
      "main" => "office_category_main",
      "PMU" => "office_pmu",
      "FCO" => "office_fco",
      "TO" => "office_to"
    },
    "LG" => {
      "main" => "lg_main",
      "State" => "lg_state",
      "District" => "lg_district",
      "Block" => "lg_block"
    },
    "Stakeholder Categories" => "stakeholder_categories",
    "Registration Types" => "registration_types",
    "Service Types" => "service_types",
    "Vendor Thematic Types" => "vendor_themes",
    "Product Entry" => "products",
    "Product Variety Entry" => "product_varieties",
    "Units" => "units",
    "Documents" => "documents",
    "Approval Channels" => "approval_channels",
    "Firms" => "firms",
    "Employee Master" => "employee_master",
    "Banks" => "banks",
    "Quotation Proposal" => {
      "main" => "quotation_proposal_main",
      "Quotation Proposal Form" => "quotation_proposal_form",
      "Quotation Proposal List" => "quotation_proposal_list"
    },
    "Vendor Registration Form" => {
      "main" => "vendor_registration_main",
      "Vendor Registration" => "vendor_registration",
      "Vendor Registration List" => "vendor_registration_list"
    },
    "Assets" => "assets",
    "Allocation" => "allocation"
  }.freeze

  def self.can_view?(stakeholder_category_id, designation, menu_identifier)
    # If no permissions are set, default to false or true? 
    # The user wants "DYNAMIC" so we should probably check if a permission exists.
    # If it's a new system, maybe we default to true if no rules exist, 
    # but the usual approach is default to false if RBAC is active.
    
    # We will check if 'can_view' is true for this combination.
    exists?({
      stakeholder_category_id: stakeholder_category_id,
      designation: designation,
      menu_identifier: menu_identifier,
      can_view: true
    })
  end
end
