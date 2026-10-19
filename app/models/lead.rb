# A request for the team to call back: a quote for a product (product
# pages), or a bidding partner for a tender (/find-a-partner)
class Lead < ApplicationRecord
  include IndianMobile

  NEEDED_BY = ['Immediately', 'Within a week', 'Within a month', 'Just comparing prices'].freeze
  PARTNER_NEEDS = ['JV or consortium partner, to meet the eligibility',
                   'Subcontractor or local partner, to do the work',
                   'Not sure yet, help me decide'].freeze

  belongs_to :product, optional: true
  belongs_to :tender, optional: true
  belongs_to :user, optional: true

  enum :kind, { quote: 'quote', partner: 'partner' }, default: 'quote'
  # Pending: nobody has called yet
  enum :status, { pending: 0, called: 1, quoted: 2, won: 3, lost: 4 }

  validates :name, :email, :phone, :location, presence: true
  validates :product, :quantity, presence: true, if: :quote?
  validates :partner_need, inclusion: { in: PARTNER_NEEDS }, if: :partner?
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :needed_by, inclusion: { in: NEEDED_BY }, allow_blank: true
  validates :annual_turnover, inclusion: { in: User::TURNOVER_BANDS }, allow_blank: true
  validates :name, :email, :quantity, :location, :company, length: { maximum: 120 }
  validates :details, length: { maximum: 2000 }

  # What the request is about, for lists
  def subject = product&.name || tender&.title.to_s.squish.truncate(70).presence || 'Bidding partner'
end
