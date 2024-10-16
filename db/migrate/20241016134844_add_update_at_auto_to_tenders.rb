class AddUpdateAtAutoToTenders < ActiveRecord::Migration[7.0]
  def change
    add_column :tenders, :updated_at_auto, :datetime, default: -> { 'CURRENT_TIMESTAMP' }
    add_index :tenders, :updated_at_auto
  end
end
