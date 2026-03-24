# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_24_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "allocations", force: :cascade do |t|
    t.date "allocated_at"
    t.bigint "asset_id", null: false
    t.datetime "created_at", null: false
    t.bigint "to_id", null: false
    t.datetime "updated_at", null: false
    t.index ["asset_id"], name: "index_allocations_on_asset_id"
    t.index ["to_id"], name: "index_allocations_on_to_id"
  end

  create_table "approval_channel_steps", force: :cascade do |t|
    t.bigint "approval_channel_id", null: false
    t.datetime "created_at", null: false
    t.string "current_action", null: false
    t.bigint "from_user_id"
    t.string "previous_action"
    t.integer "step_number", null: false
    t.bigint "to_responsible_user_id", null: false
    t.datetime "updated_at", null: false
    t.index ["approval_channel_id", "step_number"], name: "idx_on_approval_channel_id_step_number_b6413af533", unique: true
    t.index ["approval_channel_id"], name: "index_approval_channel_steps_on_approval_channel_id"
    t.index ["from_user_id"], name: "index_approval_channel_steps_on_from_user_id"
    t.index ["to_responsible_user_id"], name: "index_approval_channel_steps_on_to_responsible_user_id"
  end

  create_table "approval_channels", force: :cascade do |t|
    t.string "approval_type"
    t.datetime "created_at", null: false
    t.string "form_name"
    t.string "level_1_approver"
    t.bigint "level_1_employee_id"
    t.string "level_2_approver"
    t.bigint "level_2_employee_id"
    t.string "level_3_approver"
    t.bigint "level_3_employee_id"
    t.bigint "stakeholder_category_id"
    t.bigint "theme_id"
    t.datetime "updated_at", null: false
    t.index ["level_1_employee_id"], name: "index_approval_channels_on_level_1_employee_id"
    t.index ["level_2_employee_id"], name: "index_approval_channels_on_level_2_employee_id"
    t.index ["level_3_employee_id"], name: "index_approval_channels_on_level_3_employee_id"
    t.index ["stakeholder_category_id"], name: "index_approval_channels_on_stakeholder_category_id"
    t.index ["theme_id"], name: "index_approval_channels_on_theme_id"
  end

  create_table "approval_requests", force: :cascade do |t|
    t.bigint "approvable_id", null: false
    t.string "approvable_type", null: false
    t.bigint "approval_channel_id", null: false
    t.datetime "created_at", null: false
    t.integer "current_level"
    t.string "form_name", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["approvable_type", "approvable_id"], name: "index_approval_requests_on_approvable"
    t.index ["approval_channel_id"], name: "index_approval_requests_on_approval_channel_id"
  end

  create_table "approval_steps", force: :cascade do |t|
    t.datetime "actioned_at"
    t.bigint "approval_request_id", null: false
    t.datetime "created_at", null: false
    t.string "current_action"
    t.bigint "employee_master_id", null: false
    t.bigint "from_user_id"
    t.integer "level", null: false
    t.string "previous_action"
    t.text "remark"
    t.string "status", default: "waiting", null: false
    t.datetime "updated_at", null: false
    t.index ["approval_request_id"], name: "index_approval_steps_on_approval_request_id"
    t.index ["employee_master_id"], name: "index_approval_steps_on_employee_master_id"
    t.index ["from_user_id"], name: "index_approval_steps_on_from_user_id"
  end

  create_table "assets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.bigint "product_id", null: false
    t.string "serial_number"
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_assets_on_product_id"
  end

  create_table "blocks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "district_id", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["district_id"], name: "index_blocks_on_district_id"
  end

  create_table "districts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.bigint "state_id", null: false
    t.datetime "updated_at", null: false
    t.index ["state_id"], name: "index_districts_on_state_id"
  end

  create_table "document_masters", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.bigint "stakeholder_category_id"
    t.datetime "updated_at", null: false
    t.index ["stakeholder_category_id"], name: "index_document_masters_on_stakeholder_category_id"
  end

  create_table "employee_masters", force: :cascade do |t|
    t.bigint "block_id"
    t.datetime "created_at", null: false
    t.string "designation"
    t.bigint "district_id"
    t.string "email_id"
    t.string "employee_code"
    t.text "full_address"
    t.string "gram_panchayat"
    t.string "location"
    t.string "mobile_no"
    t.string "name", null: false
    t.string "office"
    t.string "parent_office"
    t.string "pincode"
    t.bigint "stakeholder_category_id", null: false
    t.bigint "state_id"
    t.datetime "updated_at", null: false
    t.string "user_type"
    t.string "village"
    t.index ["block_id"], name: "index_employee_masters_on_block_id"
    t.index ["district_id"], name: "index_employee_masters_on_district_id"
    t.index ["employee_code"], name: "index_employee_masters_on_employee_code", unique: true
    t.index ["stakeholder_category_id"], name: "index_employee_masters_on_stakeholder_category_id"
    t.index ["state_id"], name: "index_employee_masters_on_state_id"
  end

  create_table "fcos", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.bigint "pmu_id", null: false
    t.datetime "updated_at", null: false
    t.index ["pmu_id"], name: "index_fcos_on_pmu_id"
  end

  create_table "firms", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.bigint "stakeholder_category_id"
    t.datetime "updated_at", null: false
    t.index ["stakeholder_category_id"], name: "index_firms_on_stakeholder_category_id"
  end

  create_table "menu_permissions", force: :cascade do |t|
    t.boolean "can_view", default: false
    t.datetime "created_at", null: false
    t.string "designation", null: false
    t.string "menu_identifier", null: false
    t.bigint "stakeholder_category_id", null: false
    t.datetime "updated_at", null: false
    t.index ["stakeholder_category_id", "designation", "menu_identifier"], name: "idx_menu_permissions_composite", unique: true
    t.index ["stakeholder_category_id"], name: "index_menu_permissions_on_stakeholder_category_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "message"
    t.bigint "notifiable_id", null: false
    t.string "notifiable_type", null: false
    t.string "status", default: "unread", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "office_categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.string "office_level"
    t.bigint "parent_id"
    t.bigint "stakeholder_category_id"
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_office_categories_on_parent_id"
    t.index ["stakeholder_category_id"], name: "index_office_categories_on_stakeholder_category_id"
  end

  create_table "pmus", force: :cascade do |t|
    t.bigint "block_id"
    t.datetime "created_at", null: false
    t.bigint "district_id", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["block_id"], name: "index_pmus_on_block_id"
    t.index ["district_id"], name: "index_pmus_on_district_id"
  end

  create_table "product_varieties", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.bigint "product_id", null: false
    t.bigint "stakeholder_category_id"
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_product_varieties_on_product_id"
    t.index ["stakeholder_category_id"], name: "index_product_varieties_on_stakeholder_category_id"
  end

  create_table "products", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.bigint "stakeholder_category_id"
    t.bigint "theme_id", null: false
    t.datetime "updated_at", null: false
    t.index ["stakeholder_category_id"], name: "index_products_on_stakeholder_category_id"
    t.index ["theme_id"], name: "index_products_on_theme_id"
  end

  create_table "registration_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.bigint "stakeholder_category_id"
    t.datetime "updated_at", null: false
    t.index ["stakeholder_category_id"], name: "index_registration_types_on_stakeholder_category_id"
  end

  create_table "service_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.bigint "stakeholder_category_id"
    t.datetime "updated_at", null: false
    t.index ["stakeholder_category_id"], name: "index_service_types_on_stakeholder_category_id"
  end

  create_table "stakeholder_categories", force: :cascade do |t|
    t.text "address"
    t.string "contact_no"
    t.datetime "created_at", null: false
    t.string "email_id"
    t.string "logo_url"
    t.string "name"
    t.bigint "office_category_id"
    t.datetime "updated_at", null: false
    t.index ["office_category_id"], name: "index_stakeholder_categories_on_office_category_id"
  end

  create_table "states", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "themes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.bigint "stakeholder_category_id"
    t.datetime "updated_at", null: false
    t.index ["stakeholder_category_id"], name: "index_themes_on_stakeholder_category_id"
  end

  create_table "tos", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "fco_id", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["fco_id"], name: "index_tos_on_fco_id"
  end

  create_table "units", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.bigint "stakeholder_category_id"
    t.datetime "updated_at", null: false
    t.index ["stakeholder_category_id"], name: "index_units_on_stakeholder_category_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "vendor_bank_masters", force: :cascade do |t|
    t.string "account_number"
    t.string "account_type"
    t.text "bank_address"
    t.string "bank_name"
    t.datetime "created_at", null: false
    t.string "ifsc_code"
    t.bigint "stakeholder_category_id"
    t.datetime "updated_at", null: false
    t.bigint "vendor_registration_id", null: false
    t.index ["stakeholder_category_id"], name: "index_vendor_bank_masters_on_stakeholder_category_id"
    t.index ["vendor_registration_id"], name: "index_vendor_bank_masters_on_vendor_registration_id"
  end

  create_table "vendor_registration_product_varieties", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "product_variety_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "vendor_registration_id", null: false
    t.index ["product_variety_id"], name: "idx_on_product_variety_id_c5a5c5dc8f"
    t.index ["vendor_registration_id"], name: "idx_on_vendor_registration_id_03a9031881"
  end

  create_table "vendor_registration_products", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "product_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "vendor_registration_id", null: false
    t.index ["product_id"], name: "index_vendor_registration_products_on_product_id"
    t.index ["vendor_registration_id"], name: "index_vendor_registration_products_on_vendor_registration_id"
  end

  create_table "vendor_registration_themes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "theme_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "vendor_registration_id", null: false
    t.index ["theme_id"], name: "index_vendor_registration_themes_on_theme_id"
    t.index ["vendor_registration_id"], name: "index_vendor_registration_themes_on_vendor_registration_id"
  end

  create_table "vendor_registrations", force: :cascade do |t|
    t.bigint "block_id", null: false
    t.text "business_description"
    t.string "company_name"
    t.string "company_status"
    t.string "contact_person_designation"
    t.string "contact_person_name"
    t.datetime "created_at", null: false
    t.bigint "district_id", null: false
    t.string "email"
    t.bigint "firm_id"
    t.string "firm_type"
    t.string "gst_no"
    t.string "mobile_no"
    t.boolean "msme"
    t.string "msme_number"
    t.string "pan_no"
    t.string "pin_no"
    t.bigint "registration_type_id", null: false
    t.bigint "stakeholder_category_id"
    t.bigint "state_id", null: false
    t.datetime "submitted_at", null: false
    t.string "submitted_ip", null: false
    t.datetime "updated_at", null: false
    t.string "vendor_name"
    t.index ["block_id"], name: "index_vendor_registrations_on_block_id"
    t.index ["district_id"], name: "index_vendor_registrations_on_district_id"
    t.index ["firm_id"], name: "index_vendor_registrations_on_firm_id"
    t.index ["registration_type_id"], name: "index_vendor_registrations_on_registration_type_id"
    t.index ["stakeholder_category_id"], name: "index_vendor_registrations_on_stakeholder_category_id"
    t.index ["state_id"], name: "index_vendor_registrations_on_state_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "allocations", "assets"
  add_foreign_key "allocations", "tos"
  add_foreign_key "approval_channel_steps", "approval_channels"
  add_foreign_key "approval_channel_steps", "employee_masters", column: "from_user_id"
  add_foreign_key "approval_channel_steps", "employee_masters", column: "to_responsible_user_id"
  add_foreign_key "approval_channels", "employee_masters", column: "level_1_employee_id"
  add_foreign_key "approval_channels", "employee_masters", column: "level_2_employee_id"
  add_foreign_key "approval_channels", "employee_masters", column: "level_3_employee_id"
  add_foreign_key "approval_channels", "stakeholder_categories"
  add_foreign_key "approval_channels", "themes"
  add_foreign_key "approval_requests", "approval_channels"
  add_foreign_key "approval_steps", "approval_requests"
  add_foreign_key "approval_steps", "employee_masters"
  add_foreign_key "approval_steps", "employee_masters", column: "from_user_id"
  add_foreign_key "assets", "products"
  add_foreign_key "blocks", "districts"
  add_foreign_key "districts", "states"
  add_foreign_key "document_masters", "stakeholder_categories"
  add_foreign_key "employee_masters", "blocks"
  add_foreign_key "employee_masters", "districts"
  add_foreign_key "employee_masters", "stakeholder_categories"
  add_foreign_key "employee_masters", "states"
  add_foreign_key "fcos", "pmus"
  add_foreign_key "firms", "stakeholder_categories"
  add_foreign_key "menu_permissions", "stakeholder_categories"
  add_foreign_key "notifications", "users"
  add_foreign_key "office_categories", "stakeholder_categories"
  add_foreign_key "pmus", "blocks"
  add_foreign_key "pmus", "districts"
  add_foreign_key "product_varieties", "products"
  add_foreign_key "product_varieties", "stakeholder_categories"
  add_foreign_key "products", "stakeholder_categories"
  add_foreign_key "products", "themes"
  add_foreign_key "registration_types", "stakeholder_categories"
  add_foreign_key "service_types", "stakeholder_categories"
  add_foreign_key "stakeholder_categories", "office_categories"
  add_foreign_key "themes", "stakeholder_categories"
  add_foreign_key "tos", "fcos"
  add_foreign_key "units", "stakeholder_categories"
  add_foreign_key "vendor_bank_masters", "stakeholder_categories"
  add_foreign_key "vendor_bank_masters", "vendor_registrations"
  add_foreign_key "vendor_registration_product_varieties", "product_varieties"
  add_foreign_key "vendor_registration_product_varieties", "vendor_registrations"
  add_foreign_key "vendor_registration_products", "products"
  add_foreign_key "vendor_registration_products", "vendor_registrations"
  add_foreign_key "vendor_registration_themes", "themes"
  add_foreign_key "vendor_registration_themes", "vendor_registrations"
  add_foreign_key "vendor_registrations", "blocks"
  add_foreign_key "vendor_registrations", "districts"
  add_foreign_key "vendor_registrations", "firms"
  add_foreign_key "vendor_registrations", "registration_types"
  add_foreign_key "vendor_registrations", "stakeholder_categories"
  add_foreign_key "vendor_registrations", "states"
end
