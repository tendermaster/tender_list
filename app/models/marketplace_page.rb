# A page products.sigmatenders.com may serve (Marketplace::PageRefresher).
# products-web reads these through the marketplace.pages view.
class MarketplacePage < ApplicationRecord
  TEMPLATES = %w[category price size-chart size grade brand state city supplier].freeze

  belongs_to :product, optional: true
  belongs_to :supplier, optional: true

  validates :path, presence: true, uniqueness: true
  validates :template, inclusion: { in: TEMPLATES }
  validates :fingerprint, :lastmod, presence: true
end
