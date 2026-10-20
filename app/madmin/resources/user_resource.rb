class UserResource < Madmin::Resource
  attribute :id, form: false
  attribute :email, index: true
  attribute :name
  attribute :phone, index: true
  attribute :business_type, index: false
  attribute :tender_values, index: false, form: false
  attribute :annual_turnover, index: false
  attribute :msme, index: false
  attribute :startup_india, index: false
  attribute :call_status, index: true
  attribute :call_note, index: false
  attribute :onboarded_at, index: false, form: false
  attribute :contact_consent_at, index: false, form: false
  attribute :role
  attribute :current_plan
  attribute :sign_in_count, index: true, form: false
  attribute :last_sign_in_at, index: true, form: false
  attribute :current_sign_in_at, index: false, form: false
  attribute :current_sign_in_ip, index: false, form: false
  attribute :last_sign_in_ip, index: false, form: false
  attribute :confirmed_at, index: true
  attribute :unconfirmed_email, index: false
  attribute :failed_attempts, index: false, form: false
  attribute :locked_at, index: false
  attribute :created_at, form: false
  attribute :google_uid, index: false, form: false
  attribute :updated_at, index: false, form: false
  # encrypted_password and the reset/confirmation/unlock tokens are never shown.

  attribute :query, index: false
  attribute :bookmarks, index: false
  attribute :subscriptions, index: false

  member_action do |user|
    button_to 'Log in as', impersonate_madmin_user_path(user), class: 'btn btn-secondary',
                                                             data: { turbo: false }
  end

  def self.display_name(record) = record.email

  # Newest first
  def self.default_sort_column = 'created_at'
  def self.default_sort_direction = 'desc'
end
