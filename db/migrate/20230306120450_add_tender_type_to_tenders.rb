class AddTenderTypeToTenders < ActiveRecord::Migration[7.0]
  def change
    add_column :tenders, :tender_category, :string
    add_column :tenders, :tender_contract_type, :string
    add_column :tenders, :tender_source, :string
  end
end
