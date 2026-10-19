class AddPartnerRequestsAndBusinessProfile < ActiveRecord::Migration[8.0]
  def change
    # Leads are product quotes or requests for a bidding partner on a tender
    change_table :leads, bulk: true do |t|
      t.string :kind, null: false, default: 'quote'
      # No foreign key: tenders is ~20 GB and rows can be removed by the scrapers
      t.bigint :tender_id, index: true
      t.string :partner_need
      t.string :company
      t.string :annual_turnover
    end
    change_column_null :leads, :product_id, true
    change_column_null :leads, :quantity, true

    # Asked at onboarding: what bidders can bring to a tender
    change_table :users, bulk: true do |t|
      t.string :annual_turnover
      t.boolean :msme
      t.boolean :startup_india
    end
  end
end
