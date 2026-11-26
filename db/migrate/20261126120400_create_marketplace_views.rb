# The marketplace.* views products-web reads (db/marketplace/views.sql). A
# later change to the views gets its own migration calling apply! again.
class CreateMarketplaceViews < ActiveRecord::Migration[8.1]
  def up
    safety_assured { Marketplace::Views.apply!(connection) }
  end

  def down
    safety_assured { execute 'DROP SCHEMA IF EXISTS marketplace CASCADE' }
  end
end
