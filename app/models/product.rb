# A product page (/products/cctv-cameras): a buying guide in Markdown and a
# "Get quote" form. Requests become Leads, which the team sources by hand.
#
# A marketplace product is also a category on products.sigmatenders.com
# (Marketplace::Catalog): its IS standards (is_numbers) link it to suppliers'
# BIS licences, and its tables feed the price, size and grade pages:
#   price_table: { "unit" => "₹ per metre", "source" => "...",
#                  "rows" => [{ "size_mm" => 32, "grade" => "PN 6", "brand" => "Supreme", "min" => 40, "max" => 52 }] }
#   spec_table:  { "standard" => "IS 4984:2016",
#                  "rows" => [{ "size_mm" => 32, "inch" => "1", "grade" => "PN 6", "od_mm" => 32,
#                               "wall_mm" => 2.0, "kg_per_m" => 0.19 }] }
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
  validate :marketplace_tables_well_formed

  before_save :add_table_slugs
  before_save :touch_marketplace_changed_at

  scope :published, -> { where(published: true) }
  scope :ordered, -> { order(:position, :name) }
  scope :in_marketplace, -> { published.where(marketplace: true) }

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

  def catalog = Marketplace::Catalog.new(self)

  private

  MARKETPLACE_FIELDS = %w[name summary body is_numbers tender_query search_term price_table spec_table marketplace
                          published].freeze

  # Each price and spec row carries its size and grade slugs, made here so
  # products-web never builds one (Marketplace.size_slug, .grade_slug)
  def add_table_slugs
    %w[price_table spec_table].each do |field|
      table = self[field]
      next unless table.is_a?(Hash) && table['rows'].is_a?(Array)

      rows = table['rows'].map do |row|
        row.merge('size_slug' => Marketplace.size_slug(row), 'grade_slug' => Marketplace.grade_slug(row['grade']))
      end
      self[field] = table.merge('rows' => rows)
    end
  end

  # Pages' lastmod: only a change shown on products.sigmatenders.com moves it
  def touch_marketplace_changed_at
    self.marketplace_changed_at = Time.current if marketplace? && (changed & MARKETPLACE_FIELDS).any?
  end

  # The keys the marketplace views cast, with their types: a string where a
  # number belongs would break products-web's queries, not just one page
  TABLE_COLUMNS = {
    'price_table' => { numbers: %w[size_mm min max], texts: %w[inch grade brand] },
    'spec_table' => { numbers: %w[size_mm od_mm wall_mm kg_per_m], texts: %w[inch grade] }
  }.freeze

  def marketplace_tables_well_formed
    TABLE_COLUMNS.each do |field, columns|
      table = self[field]
      rows = table.is_a?(Hash) ? table.fetch('rows', []) : nil
      unless rows.is_a?(Array) && rows.all?(Hash)
        errors.add(field, 'must be {"rows" => [{...}, ...]}')
        next
      end
      rows.each_with_index do |row, i|
        errors.add(field, "row #{i + 1}: size_mm is required") unless row['size_mm'].is_a?(Numeric)
        bad = columns[:numbers].reject { row[_1].nil? || row[_1].is_a?(Numeric) } +
              columns[:texts].reject { row[_1].nil? || row[_1].is_a?(String) }
        errors.add(field, "row #{i + 1}: wrong type for #{bad.join(', ')}") if bad.any?
      end
    end
  end

  def configurations_well_formed
    valid = ->(c) { c.is_a?(Hash) && c['key'].to_s.match?(/\A[a-z0-9-]+\z/) && c['name'].present? && c['attributes'].is_a?(Hash) }
    return if configurations.is_a?(Array) && configurations.all?(&valid)

    errors.add(:configurations, 'must be a list of {key, name, summary, attributes}')
  end
end
