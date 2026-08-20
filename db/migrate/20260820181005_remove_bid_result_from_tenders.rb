class RemoveBidResultFromTenders < ActiveRecord::Migration[7.0]
  def up
    remove_index :tenders, name: :idx_tenders_bid_result_id, if_exists: true
    remove_column :tenders, :bid_result, :text
  end

  def down
    add_column :tenders, :bid_result, :text
  end
end
