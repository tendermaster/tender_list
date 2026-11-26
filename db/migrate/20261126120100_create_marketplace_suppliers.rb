# products.sigmatenders.com: manufacturers, seeded from BIS licence reports
# (Bis::LicenceImporter), and their licences
class CreateMarketplaceSuppliers < ActiveRecord::Migration[8.1]
  def change
    create_table :suppliers do |t|
      t.string :name, null: false
      t.string :slug, null: false
      # Normalised name + PIN: how an import recognises a supplier it has seen
      t.string :identity_key, null: false
      t.text :address
      t.string :pincode
      t.string :district
      t.string :state
      # URL slugs are made in Ruby (Marketplace) and stored, so products-web
      # never builds one
      t.string :state_slug
      t.string :gstin
      t.string :gem_seller_id
      t.string :website
      # Shown only once the supplier claims the listing
      t.string :phone
      t.integer :status, null: false, default: 0
      t.string :source, null: false, default: 'bis'
      t.datetime :claimed_at
      t.timestamps
    end
    add_index :suppliers, :slug, unique: true
    add_index :suppliers, :identity_key, unique: true
    add_index :suppliers, :state

    create_table :bis_licences do |t|
      t.references :supplier, null: false, foreign_key: true
      t.string :cml_no, null: false
      t.string :standard, null: false
      t.string :is_number, null: false
      t.string :brands, array: true, null: false, default: []
      t.text :variety
      # Parsed from variety: sizes_mm, pn, sdr, pe, classes, types
      t.jsonb :grades, null: false, default: {}
      # Made in Ruby (Marketplace): brands, grades (pn-6, class-b)
      t.jsonb :slugs, null: false, default: {}
      t.string :status, null: false
      t.date :granted_on
      t.date :valid_until
      t.date :last_seen_on
      # When status, brands or variety last changed (pages' lastmod)
      t.datetime :data_changed_at
      t.jsonb :raw, null: false, default: {}
      t.timestamps
    end
    add_index :bis_licences, :cml_no, unique: true
    add_index :bis_licences, %i[is_number status]
  end
end
