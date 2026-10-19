# A product page (/products/cctv-cameras): a buying guide in Markdown and a
# "Get quote" form. Requests become Leads, which the team sources by hand.
class Product < ApplicationRecord
  CATEGORIES = ['IT & Electronics', 'Electrical & Power', 'Water & Sanitation', 'Furniture',
                'Medical & Laboratory', 'Vehicles, Safety & Other'].freeze

  has_many :leads, dependent: :restrict_with_error

  validates :name, :summary, :body, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :category, inclusion: { in: CATEGORIES }
  validates :summary, length: { maximum: 160 }

  scope :published, -> { where(published: true) }
  scope :ordered, -> { order(:position, :name) }

  def to_param = slug

  def related(limit = 6) = Product.published.where(category:).where.not(id:).ordered.limit(limit)

  # Raw HTML in the Markdown is dropped, as in blog posts
  def body_html = Commonmarker.to_html(body.to_s, options: BlogPost::MARKDOWN_OPTIONS)
end
