# Products moved to products.sigmatenders.com, its own app and `products`
# database (docs/decisions.md, 2026-11-26): its suppliers, BIS licences,
# pages and the views it read leave this database. Old quote requests keep
# their product (products table).
class RemoveMarketplace < ActiveRecord::Migration[8.1]
  def up
    safety_assured do
      execute 'DROP SCHEMA IF EXISTS marketplace CASCADE'
      remove_reference :leads, :supplier, foreign_key: true, index: true
      drop_table :marketplace_pages
      drop_table :bis_licences
      drop_table :suppliers
      remove_columns :products, :marketplace, :is_numbers, :tender_query, :search_term, :price_table,
                     :price_updated_on, :spec_table, :marketplace_changed_at
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'the marketplace lives in the products database now'
  end
end
