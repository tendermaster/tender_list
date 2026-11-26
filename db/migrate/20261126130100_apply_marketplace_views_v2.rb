# marketplace.* views gain page copy, the search term and display names
# (columns added at the end: products-web keeps working until it uses them)
class ApplyMarketplaceViewsV2 < ActiveRecord::Migration[8.1]
  def up
    safety_assured { Marketplace::Views.apply!(connection) }
  end

  def down; end
end
