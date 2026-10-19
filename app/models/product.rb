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

  # <title> is capped at 70 characters including the "Sigma Tenders | " prefix
  def seo_title
    ["#{name}: Buying Guide & Quotes", "#{name}: Get Quotes", name].find { |title| title.size <= 54 } || name.truncate(54)
  end

  # The "### Question?" headings under "## Frequently asked questions" and the
  # text below each, as [question, answer] pairs (for FAQPage structured data)
  def faqs
    section = body.to_s.split(/^## Frequently asked questions\s*$/i, 2)[1].to_s.split(/^## /, 2).first.to_s
    section.split(/^### /).drop(1).filter_map do |block|
      question, answer = block.split("\n", 2).map { |text| text.to_s.squish }
      [question, answer.gsub(/[*_`]/, '')] if question.present? && answer.present?
    end
  end
end
