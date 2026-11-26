# Everything a products.sigmatenders.com page says about itself is made in
# Ruby (Marketplace::Catalog) and stored, so products-web builds no titles,
# labels or slugs: title, description, h1, breadcrumbs and template data.
class AddPageCopyToMarketplace < ActiveRecord::Migration[8.1]
  def change
    add_column :marketplace_pages, :title, :string
    add_column :marketplace_pages, :description, :string
    add_column :marketplace_pages, :h1, :string
    add_column :marketplace_pages, :breadcrumbs, :jsonb, null: false, default: []
    add_column :marketplace_pages, :data, :jsonb, null: false, default: {}
    # How buyers search for the product: "HDPE pipe", "hand pump"
    add_column :products, :search_term, :string
    # The BIS name in readable case: "Sri Madhura Polymers Pvt Ltd"
    add_column :suppliers, :display_name, :string
  end
end
