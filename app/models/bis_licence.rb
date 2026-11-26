# A BIS product licence (CM/L): which standard a supplier is licensed for,
# under which brands, for which sizes and grades (parsed from "Variety" by
# Bis::VarietyParser), and whether it is still Operative.
class BisLicence < ApplicationRecord
  belongs_to :supplier, touch: false

  OPERATIVE = 'Operative'

  validates :cml_no, presence: true, uniqueness: true
  validates :standard, :is_number, :status, presence: true

  scope :operative, -> { where(status: OPERATIVE) }

  # Slugs are made here, in Ruby, and stored: products-web reads them
  before_save do
    self.slugs = { 'brands' => brands.filter_map { Marketplace.slug(_1) }.uniq,
                   'grades' => Marketplace.licence_grade_slugs(grades, is_number) }
  end

  def operative? = status == OPERATIVE

  def sizes_mm = Array(grades['sizes_mm'])
end
