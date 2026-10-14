class Bookmark < ApplicationRecord
  belongs_to :user
  belongs_to :tender

  validates :tender_id, uniqueness: { scope: :user_id }
end
