class AddSearchkick < ActiveRecord::Migration[7.0]
  def change
    add_column :tenders, :search_conversions, :jsonb
  end
end
