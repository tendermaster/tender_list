# A product page (/products/cctv-cameras): a buying guide in Markdown and a
# "Get quote" form. Requests become Leads, which the team sources by hand.
class Product < ApplicationRecord
  CATEGORIES = ['IT & Electronics', 'Electrical & Power', 'Water & Sanitation', 'Furniture',
                'Medical & Laboratory', 'Vehicles, Safety & Other'].freeze

  # A "Choose your requirement" card: a sourcing brief with typical values,
  # not a model in stock
  Configuration = Data.define(:key, :name, :summary, :attributes)

  # What the team asks suppliers to put in a quote, unless a product says otherwise
  QUOTE_INCLUDES = ['Exact make, model and specifications offered', 'Unit price and GST',
                    'Delivery charges and time to your location', 'Installation, if needed',
                    'Warranty and after-sales service'].freeze

  has_many :leads, dependent: :restrict_with_error

  validates :name, :summary, :body, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :category, inclusion: { in: CATEGORIES }
  validates :summary, length: { maximum: 160 }
  validate :configurations_well_formed

  scope :published, -> { where(published: true) }
  scope :ordered, -> { order(:position, :name) }

  def to_param = slug

  def configuration_list
    Array(configurations).map do |c|
      Configuration.new(key: c['key'], name: c['name'], summary: c['summary'], attributes: c['attributes'].to_h)
    end
  end

  # The comparison table's rows: every attribute label, in first-seen order
  def configuration_labels = configuration_list.flat_map { _1.attributes.keys }.uniq

  def configuration_named(name) = configuration_list.find { _1.name == name }

  def related(limit = 6) = Product.published.where(category:).where.not(id:).ordered.limit(limit)

  # Raw HTML in the Markdown is dropped, as in blog posts. Headings move down
  # a level: the guide sits under the page's "Buying guide" heading.
  def body_html = Commonmarker.to_html(body.to_s.gsub(/^(\#{1,5}) /, '#\\1 '), options: BlogPost::MARKDOWN_OPTIONS)

  # <title> is capped at 70 characters including the "Sigma Tenders | " prefix
  def seo_title
    ["#{name}: Compare & Request a Quote", "#{name}: Request a Quote", name].find { |title| title.size <= 54 } || name.truncate(54)
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

  private

  def configurations_well_formed
    valid = ->(c) { c.is_a?(Hash) && c['key'].to_s.match?(/\A[a-z0-9-]+\z/) && c['name'].present? && c['attributes'].is_a?(Hash) }
    return if configurations.is_a?(Array) && configurations.all?(&valid)

    errors.add(:configurations, 'must be a list of {key, name, summary, attributes}')
  end
end
