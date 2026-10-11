# frozen_string_literal: true

# Google's stable account id (the ID token's "sub"). Signing in matched users
# by email only; an address can change or be reassigned, the id can't.
class AddGoogleUidToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :google_uid, :string
    add_index :users, :google_uid, unique: true
  end
end
