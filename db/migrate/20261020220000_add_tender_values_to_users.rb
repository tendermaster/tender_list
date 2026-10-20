class AddTenderValuesToUsers < ActiveRecord::Migration[8.0]
  def change
    # Onboarding: the tender sizes a user bids on (User::TENDER_VALUE_BANDS)
    add_column :users, :tender_values, :string, array: true, null: false, default: []
  end
end
