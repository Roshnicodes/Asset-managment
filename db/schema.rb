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

ActiveRecord::Schema[8.1].define(version: 2026_03_17_041528) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "allocations", force: :cascade do |t|
    t.date "allocated_at"
    t.bigint "asset_id", null: false
    t.datetime "created_at", null: false
    t.bigint "to_id", null: false
    t.datetime "updated_at", null: false
    t.index ["asset_id"], name: "index_allocations_on_asset_id"
    t.index ["to_id"], name: "index_allocations_on_to_id"
  end

  create_table "assets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.bigint "product_id", null: false
    t.string "serial_number"
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_assets_on_product_id"
  end

  create_table "districts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.bigint "state_id", null: false
    t.datetime "updated_at", null: false
    t.index ["state_id"], name: "index_districts_on_state_id"
  end

  create_table "fcos", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.bigint "pmu_id", null: false
    t.datetime "updated_at", null: false
    t.index ["pmu_id"], name: "index_fcos_on_pmu_id"
  end

  create_table "pmus", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "district_id", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["district_id"], name: "index_pmus_on_district_id"
  end

  create_table "products", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.bigint "theme_id", null: false
    t.datetime "updated_at", null: false
    t.index ["theme_id"], name: "index_products_on_theme_id"
  end

  create_table "states", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "themes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "tos", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "fco_id", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["fco_id"], name: "index_tos_on_fco_id"
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

  add_foreign_key "allocations", "assets"
  add_foreign_key "allocations", "tos"
  add_foreign_key "assets", "products"
  add_foreign_key "districts", "states"
  add_foreign_key "fcos", "pmus"
  add_foreign_key "pmus", "districts"
  add_foreign_key "products", "themes"
  add_foreign_key "tos", "fcos"
end
