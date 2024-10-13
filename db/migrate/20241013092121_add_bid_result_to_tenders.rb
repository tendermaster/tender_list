class AddBidResultToTenders < ActiveRecord::Migration[7.0]
  def change
    add_column :tenders, :bid_result, :text
    add_column :tenders, :bid_result_status, :text
    add_column :tenders, :bid_result_updated_at, :datetime, default: -> { 'CURRENT_TIMESTAMP' }
  end
end
