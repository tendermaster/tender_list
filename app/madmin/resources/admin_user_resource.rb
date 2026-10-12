class AdminUserResource < Madmin::Resource
  attribute :id, form: false
  attribute :email, index: true
  attribute :password, :password, index: false, show: false
  attribute :password_confirmation, :password, index: false, show: false
  attribute :remember_created_at, index: false, form: false
  attribute :created_at, form: false
  attribute :updated_at, index: false, form: false
  # encrypted_password and reset tokens are never shown.

  def self.display_name(record) = record.email

  # Newest first
  def self.default_sort_column = 'created_at'
  def self.default_sort_direction = 'desc'
end
