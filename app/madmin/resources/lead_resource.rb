class LeadResource < Madmin::Resource
  attribute :id, form: false
  attribute :created_at, form: false
  attribute :kind, index: true
  attribute :product, index: true
  # Read-only: a form select would list every tender
  attribute :tender, form: false
  attribute :topic, index: true, form: false
  attribute :answers, form: false
  attribute :partner_need
  attribute :name, index: true
  attribute :company
  attribute :phone, index: true
  attribute :email, index: true
  attribute :quantity, index: true
  attribute :location, index: true
  attribute :annual_turnover
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
  scope :spam
  scope :quote
  scope :partner
  scope :enquiry

  def self.display_name(record) = "#{record.name} · #{record.subject}"

  # Newest first
  def self.default_sort_column = 'created_at'
  def self.default_sort_direction = 'desc'
end
