class ApiKeyResource < Madmin::Resource
  # New keys get a generated token; give the partner the token from the key's page
  attribute :id, form: false
  attribute :name, index: true
  attribute :token, index: false, form: false
  attribute :token_prefix, index: true, form: false
  attribute :active, index: true
  attribute :last_used_at, index: true, form: false
  attribute :requests_count, index: true, form: false
  attribute :created_at, form: false

  def self.display_name(record) = "#{record.name} (#{record.token_prefix}…)"
end
