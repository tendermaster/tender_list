class Query < ApplicationRecord
  belongs_to :user

  validates :name, length: { minimum: 1 }
  validates :include_keyword, length: { minimum: 1 }
  validates :updates, inclusion: ['WEEKLY', 'MONTHLY', 'NONE']

  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "exclude_keyword", "id", "include_keyword", "last_sent", "name", "query_type", "state_name", "updated_at", "updates", "user_id"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["user"]
  end

end
