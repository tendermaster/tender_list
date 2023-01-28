class ChangeSearchDataCol < ActiveRecord::Migration[7.0]
  def change
    rename_column :tenders, :search_data, :tender_search_data
  end
end
