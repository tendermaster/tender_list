class MiscDataStore < ApplicationRecord
  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "data", "id", "name", "note", "source", "updated_at"]
  end
end
