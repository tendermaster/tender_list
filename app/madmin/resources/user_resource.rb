class UserResource < Madmin::Resource
  attribute :id, form: false
  attribute :email
  attribute :name
  attribute :role
  attribute :current_plan
  attribute :sign_in_count, form: false
  attribute :last_sign_in_at, form: false
  attribute :current_sign_in_at, index: false, form: false
  attribute :current_sign_in_ip, index: false, form: false
  attribute :last_sign_in_ip, index: false, form: false
  attribute :confirmed_at, index: false
  attribute :unconfirmed_email, index: false
  attribute :failed_attempts, index: false, form: false
  attribute :locked_at, index: false
  attribute :created_at, form: false
  attribute :updated_at, index: false, form: false
  # encrypted_password and the reset/confirmation/unlock tokens are never shown.

  attribute :query, index: false
  attribute :bookmarks, index: false
  attribute :subscriptions, index: false

  def self.display_name(record) = record.email
end
