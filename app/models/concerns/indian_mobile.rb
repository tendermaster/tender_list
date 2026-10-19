# A `phone` column holding an Indian mobile number, stored as +91XXXXXXXXXX
module IndianMobile
  extend ActiveSupport::Concern

  included do
    before_validation :normalize_phone
    validates :phone, phone: { possible: false, types: [:mobile], countries: :in }, allow_blank: true
  end

  private

  def normalize_phone
    return if phone.blank?

    parsed = Phonelib.parse(phone, 'IN')
    self.phone = parsed.e164 if parsed.valid?
  end
end
