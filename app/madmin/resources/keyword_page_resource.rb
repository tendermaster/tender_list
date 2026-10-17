class KeywordPageResource < Madmin::Resource
  attribute :id, form: false
  attribute :name, index: true
  attribute :include_keyword, index: true
  attribute :exclude_keyword
  attribute :updated_at, form: false

  member_action do |page|
    link_to 'View page', page.path, class: 'btn btn-secondary', target: '_blank', rel: 'noopener'
  end

  def self.display_name(record) = record.name

  def self.default_sort_column = 'name'
  def self.default_sort_direction = 'asc'
end
