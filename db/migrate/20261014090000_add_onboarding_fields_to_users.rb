# frozen_string_literal: true

# What a new user tells us in onboarding (/welcome), so the team can call
# them, and how that call went. What they bid on is saved as their first Query.
class AddOnboardingFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    change_table :users, bulk: true do |t|
      t.string :phone
      t.datetime :contact_consent_at
      t.string :business_type
      t.datetime :onboarded_at
      t.string :call_status
      t.text :call_note
    end
  end
end
