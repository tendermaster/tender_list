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

ActiveRecord::Schema[7.0].define(version: 2024_01_09_105401) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_admin_comments", force: :cascade do |t|
    t.string "namespace"
    t.text "body"
    t.string "resource_type"
    t.bigint "resource_id"
    t.string "author_type"
    t.bigint "author_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "index_active_admin_comments_on_author"
    t.index ["namespace"], name: "index_active_admin_comments_on_namespace"
    t.index ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource"
  end

  create_table "admin_users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
  end

  create_table "attachments", force: :cascade do |t|
    t.string "file_name"
    t.string "file_path"
    t.string "file_text"
    t.string "download_link"
    t.string "download_status"
    t.bigint "tender_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.virtual "file_text_vector", type: :tsvector, as: "to_tsvector('english'::regconfig, (file_text)::text)", stored: true
    t.index ["file_path"], name: "index_attachments_on_file_path", unique: true
    t.index ["file_text_vector"], name: "file_text_vector_idx", using: :gin
    t.index ["tender_id"], name: "index_attachments_on_tender_id"
  end

  create_table "bookmarks", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "tender_id", null: false
    t.string "personal_note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tender_id"], name: "index_bookmarks_on_tender_id"
    t.index ["user_id"], name: "index_bookmarks_on_user_id"
  end

  create_table "misc_data_stores", force: :cascade do |t|
    t.json "data"
    t.string "name"
    t.string "source"
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "queries", force: :cascade do |t|
    t.string "name"
    t.string "query_type"
    t.text "state_name"
    t.text "include_keyword"
    t.text "exclude_keyword"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "updates", default: "WEEKLY"
    t.datetime "last_sent", default: -> { "CURRENT_TIMESTAMP" }
    t.index ["user_id"], name: "index_queries_on_user_id"
  end

  create_table "search_queries", force: :cascade do |t|
    t.string "query"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.binary "key", null: false
    t.binary "value", null: false
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_solid_cache_entries_on_key", unique: true
  end

  create_table "subscriptions", force: :cascade do |t|
    t.string "plan_name"
    t.string "order_id"
    t.decimal "price", precision: 12, scale: 2
    t.datetime "start_date"
    t.datetime "end_date"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["end_date"], name: "index_subscriptions_on_end_date"
    t.index ["order_id"], name: "index_subscriptions_on_order_id"
    t.index ["plan_name"], name: "index_subscriptions_on_plan_name"
    t.index ["user_id"], name: "index_subscriptions_on_user_id"
  end

  create_table "tenders", force: :cascade do |t|
    t.string "tender_id"
    t.text "title"
    t.text "description"
    t.text "organisation"
    t.string "state"
    t.bigint "tender_value"
    t.bigint "tender_fee"
    t.bigint "emd"
    t.datetime "bid_open_date"
    t.datetime "submission_open_date"
    t.datetime "submission_close_date"
    t.text "tender_search_data"
    t.string "slug"
    t.string "slug_uuid"
    t.boolean "is_visible"
    t.string "page_link"
    t.text "full_data"
    t.datetime "batch_time"
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", null: false
    t.jsonb "search_conversions"
    t.string "tender_category"
    t.string "tender_contract_type"
    t.string "tender_source"
    t.string "tender_reference_number"
    t.jsonb "location"
    t.virtual "tender_text_vector", type: :tsvector, as: "to_tsvector('english'::regconfig, ((((((((((((((((((((((COALESCE(tender_id, ''::character varying))::text || ' '::text) || COALESCE(title, ''::text)) || ' '::text) || COALESCE(description, ''::text)) || ' '::text) || COALESCE(organisation, ''::text)) || ' '::text) || (COALESCE(state, ''::character varying))::text) || ' '::text) || (COALESCE(slug_uuid, ''::character varying))::text) || ' '::text) || (COALESCE(page_link, ''::character varying))::text) || ' '::text) || (COALESCE(tender_category, ''::character varying))::text) || ' '::text) || (COALESCE(tender_contract_type, ''::character varying))::text) || ' '::text) || (COALESCE(tender_source, ''::character varying))::text) || ' '::text) || (COALESCE(tender_reference_number, ''::character varying))::text) || ' '::text))", stored: true
    t.index ["created_at"], name: "index_tenders_on_created_at"
    t.index ["emd"], name: "index_tenders_on_emd"
    t.index ["is_visible"], name: "index_tenders_on_is_visible"
    t.index ["slug_uuid"], name: "index_tenders_on_slug_uuid", unique: true
    t.index ["submission_close_date"], name: "index_tenders_on_submission_close_date"
    t.index ["tender_id"], name: "index_tenders_on_tender_id"
    t.index ["tender_reference_number"], name: "index_tenders_on_tender_reference_number"
    t.index ["tender_text_vector"], name: "tender_text_vector_idx", using: :gin
    t.index ["tender_value"], name: "index_tenders_on_tender_value"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.string "name", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "role", default: "USER"
    t.string "current_plan", default: "FREE"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "attachments", "tenders"
  add_foreign_key "bookmarks", "tenders"
  add_foreign_key "bookmarks", "users"
  add_foreign_key "queries", "users"
  add_foreign_key "subscriptions", "users"
end
