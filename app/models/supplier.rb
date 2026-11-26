# A manufacturer listed on products.sigmatenders.com. Seeded from BIS licence
# reports (Bis::LicenceImporter): business name and works address are public
# BIS data. The phone is shown only once the supplier claims the listing.
class Supplier < ApplicationRecord
  has_many :bis_licences, dependent: :destroy
  has_many :leads, dependent: :nullify

  enum :status, { listed: 0, claimed: 1, hidden: 2 }

  validates :name, :slug, :identity_key, presence: true
  validates :slug, :identity_key, uniqueness: true

  before_validation :set_slug, on: :create
  before_save do
    self.state_slug = Marketplace.slug(state)
    self.display_name = Marketplace.display_name(name)
  end

  scope :visible, -> { where.not(status: :hidden) }
  # Has at least one Operative licence for one of these IS numbers
  scope :operative_for, lambda { |is_numbers|
    where(id: BisLicence.operative.where(is_number: is_numbers).select(:supplier_id))
  }

  def to_param = slug

  # How imports recognise a supplier: its name without legal suffixes and
  # punctuation, plus its PIN
  def self.identity_key_for(name, pincode)
    base = name.to_s.downcase.gsub(/\b(?:m\/s|pvt|private|ltd|limited|llp|co|company|the)\b/, ' ')
    "#{base.parameterize}-#{pincode.to_s.strip}"
  end

  def operative_licences = bis_licences.operative

  def is_numbers = operative_licences.distinct.pluck(:is_number)

  def brands = operative_licences.flat_map(&:brands).uniq { _1.downcase }

  # When anything shown on its page last changed
  def data_changed_at = [updated_at, bis_licences.maximum(:data_changed_at)].compact.max

  private

  def set_slug
    return if slug.present? || name.blank?

    base = [name.parameterize.first(60).delete_suffix('-'), district.to_s.parameterize.presence].compact.join('-')
    candidate = base
    suffix = 1
    candidate = "#{base}-#{suffix += 1}" while Supplier.exists?(slug: candidate)
    self.slug = candidate
  end
end
