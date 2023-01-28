class TenderChangeIntToBigint < ActiveRecord::Migration[7.0]
  def change
    change_table :tenders do |t|
      t.change :tender_value, :bigint
      t.change :tender_fee, :bigint
      t.change :emd, :bigint
    end
  end
end
