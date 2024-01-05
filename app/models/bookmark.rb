class Bookmark < ApplicationRecord
  belongs_to :user
  belongs_to :tender

  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "id", "personal_note", "tender_id", "updated_at", "user_id"]
  end
end
