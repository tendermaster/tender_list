# A product from the old /products pages (2026-10 to 2026-11), kept so past
# quote requests (Lead#product) still show what they were about. Products
# moved to products.sigmatenders.com, its own app and database
# (docs/decisions.md, 2026-11-26); /products redirects there.
class Product < ApplicationRecord
  has_many :leads, dependent: :restrict_with_error

  validates :name, :slug, presence: true

  def to_param = slug
end
