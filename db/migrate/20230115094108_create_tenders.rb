class CreateTenders < ActiveRecord::Migration[7.0]
  def change
    create_table :tenders do |t|
      t.string :tender_id, index: true
      t.string :title
      t.text :description
      t.string :organisation
      t.string :state
      t.integer :tender_value
      t.integer :tender_fee
      t.integer :emd
      t.datetime :bid_open_date
      t.datetime :submission_open_date
      t.datetime :submission_close_date
      t.text :search_data, type: :fulltext
      t.string :slug
      t.string :slug_uuid, index: { unique: true }
      t.boolean :is_visible
      t.string :page_link
      t.text :full_data
      t.datetime :batch_time

      t.timestamps
    end
  end
end
