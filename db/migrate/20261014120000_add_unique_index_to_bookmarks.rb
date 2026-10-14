# frozen_string_literal: true

# One bookmark per user and tender, so a double click can't save it twice
class AddUniqueIndexToBookmarks < ActiveRecord::Migration[8.0]
  def change
    add_index :bookmarks, %i[user_id tender_id], unique: true
  end
end
