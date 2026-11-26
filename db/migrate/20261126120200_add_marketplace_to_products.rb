# A Product can be a category on products.sigmatenders.com: its IS standards
# link it to BIS licences; price and spec tables feed the price, size and
# grade pages
class AddMarketplaceToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :marketplace, :boolean, null: false, default: false
    add_column :products, :is_numbers, :string, array: true, null: false, default: []
    add_column :products, :tender_query, :string
    add_column :products, :price_table, :jsonb, null: false, default: {}
    add_column :products, :price_updated_on, :date
    add_column :products, :spec_table, :jsonb, null: false, default: {}
    add_column :products, :marketplace_changed_at, :datetime
  end
end
