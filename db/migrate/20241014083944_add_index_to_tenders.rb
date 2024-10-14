class AddIndexToTenders < ActiveRecord::Migration[7.0]
  def change
    add_index :tenders, :tender_source
    add_index :tenders, :bid_result_status
  end
end
