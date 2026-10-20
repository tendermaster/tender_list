# A request for the team to call back: a quote for a product (product
# pages), a bidding partner for a tender (/find-a-partner), or an enquiry
# (/enquiry/<topic>, the forms that replaced the Google Forms)
class Lead < ApplicationRecord
  NEEDED_BY = ['Immediately', 'Within a week', 'Within a month', 'Just comparing prices'].freeze
  PARTNER_NEEDS = ['JV or consortium partner, to meet the eligibility',
                   'Subcontractor or local partner, to do the work',
                   'Not sure yet, help me decide'].freeze

  belongs_to :product, optional: true
  belongs_to :tender, optional: true
  belongs_to :user, optional: true

  enum :kind, { quote: 'quote', partner: 'partner', enquiry: 'enquiry' }, default: 'quote'
  # Pending: nobody has called yet. Spam: caught by SpamFilter, kept for review
  enum :status, { pending: 0, called: 1, quoted: 2, won: 3, lost: 4, spam: 5 }

  before_validation :normalize_phone

  validates :name, :email, :phone, presence: true
  validates :location, presence: true, unless: :enquiry?
  validates :product, :quantity, presence: true, if: :quote?
  validates :partner_need, inclusion: { in: PARTNER_NEEDS }, if: :partner?
  validates :topic, inclusion: { in: ->(_) { EnquiryTopic.all.keys } }, if: :enquiry?
  validate :enquiry_answered, if: -> { enquiry? && enquiry_topic }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :email, 'valid_email_2/email': { disposable: true, message: 'is from a throwaway email service' },
                    allow_blank: true
  validate :phone_valid
  validates :needed_by, inclusion: { in: NEEDED_BY }, allow_blank: true
  validates :annual_turnover, inclusion: { in: User::TURNOVER_BANDS }, allow_blank: true
  validates :name, :email, :quantity, :location, :company, length: { maximum: 120 }
  validates :details, length: { maximum: 2000 }

  def enquiry_topic = (EnquiryTopic.find(topic) if topic.present?)

  # What the request is about, for lists
  def subject
    product&.name || enquiry_topic&.title || tender&.title.to_s.squish.truncate(70).presence || 'Bidding partner'
  end

  private

  # Indian numbers in any format, stored as +91XXXXXXXXXX; numbers from
  # other countries (enquiries come from Bangladesh, Sri Lanka, Egypt...)
  # with their country code
  def normalize_phone
    return if phone.blank?

    parsed = Phonelib.parse(phone.to_s.strip.sub(/\A00/, '+'), 'IN')
    self.phone = parsed.e164 if parsed.valid?
  end

  def phone_valid
    return if phone.blank? || Phonelib.valid?(phone)

    errors.add(:phone, 'is not a valid number (for a number outside India, start with the country code, e.g. +880)')
  end

  def enquiry_answered
    enquiry_topic.missing(answers, company:).each { |message| errors.add(:base, message) }
  end
end
