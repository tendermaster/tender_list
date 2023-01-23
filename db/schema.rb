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

ActiveRecord::Schema[7.0].define(version: 2023_01_15_094611) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "attachments", force: :cascade do |t|
    t.string "file_name"
    t.string "file_path"
    t.bigint "tender_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tender_id"], name: "index_attachments_on_tender_id"
  end

  create_table "posts", force: :cascade do |t|
    t.string "title"
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tenders", force: :cascade do |t|
    t.string "tenderId"
    t.string "title"
    t.text "description"
    t.string "organisation"
    t.string "state"
    t.integer "tender_value"
    t.integer "tender_fee"
    t.integer "emd"
    t.datetime "bid_open_date"
    t.datetime "submission_open_date"
    t.datetime "submission_close_date"
    t.text "search_data"
    t.string "slug"
    t.string "slug_uuid"
    t.boolean "is_visible"
    t.string "page_link"
    t.text "full_data"
    t.datetime "batch_time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug_uuid"], name: "index_tenders_on_slug_uuid", unique: true
  end

  add_foreign_key "attachments", "tenders"
end
