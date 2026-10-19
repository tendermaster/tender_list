# A "Get quote" request from a product page, for the team to call back
class Lead < ApplicationRecord
  include IndianMobile

  NEEDED_BY = ['Immediately', 'Within a week', 'Within a month', 'Just comparing prices'].freeze

  belongs_to :product
  belongs_to :user, optional: true

  # Pending: nobody has called yet
  enum :status, { pending: 0, called: 1, quoted: 2, won: 3, lost: 4 }

  validates :name, :email, :phone, :quantity, :location, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :needed_by, inclusion: { in: NEEDED_BY }, allow_blank: true
  validates :name, :email, :quantity, :location, length: { maximum: 120 }
  validates :details, length: { maximum: 2000 }
end
