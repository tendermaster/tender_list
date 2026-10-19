class ProductResource < Madmin::Resource
  attribute :id, form: false
  attribute :name, index: true
  attribute :slug, index: true
  attribute :category, index: true
  attribute :summary
  attribute :body # Markdown: ## sections, - bullets, ### FAQ questions
  attribute :position
  attribute :published, index: true
  attribute :updated_at, form: false
  attribute :leads, form: false

  member_action do |product|
    link_to 'View page', "/products/#{product.slug}", class: 'btn btn-secondary', target: '_blank', rel: 'noopener'
  end

  def self.display_name(record) = record.name

  def self.default_sort_column = 'position'
  def self.default_sort_direction = 'asc'
end
