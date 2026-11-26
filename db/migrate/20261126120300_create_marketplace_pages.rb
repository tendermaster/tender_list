# Every page products.sigmatenders.com may serve, written by
# Marketplace::PageRefresher from Marketplace::Catalog: products-web routes,
# pre-renders and builds its sitemaps from this (through the marketplace.pages
# view), so the rules for which pages exist and are indexable live only here.
class CreateMarketplacePages < ActiveRecord::Migration[8.1]
  def change
    create_table :marketplace_pages do |t|
      t.string :path, null: false
      t.string :template, null: false
      t.string :key
      t.references :product, foreign_key: true
      t.references :supplier, foreign_key: true
      t.boolean :indexable, null: false, default: false
      # Of the data the page shows; lastmod moves only when it changes
      t.string :fingerprint, null: false
      t.datetime :lastmod, null: false
      t.timestamps
    end
    add_index :marketplace_pages, :path, unique: true
    add_index :marketplace_pages, %i[template indexable]
  end
end
