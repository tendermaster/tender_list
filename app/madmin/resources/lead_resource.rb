class LeadResource < Madmin::Resource
  attribute :id, form: false
  attribute :created_at, form: false
  attribute :product, index: true
  attribute :name, index: true
  attribute :phone, index: true
  attribute :email, index: true
  attribute :quantity, index: true
  attribute :location, index: true
  attribute :needed_by
  attribute :details
  attribute :status, index: true
  attribute :note
  attribute :user, form: false
  attribute :updated_at, form: false

  scope :pending
  scope :called
  scope :quoted
  scope :won

  def self.display_name(record) = "#{record.name} · #{record.product&.name}"

  # Newest first
  def self.default_sort_column = 'created_at'
  def self.default_sort_direction = 'desc'
end
