# A partner's key for /api/v1/search. Created in /admin/api_keys (or with
# `bin/rails "api_keys:create[Partner name]"`), where admins can view it
# again. Requests are matched on its SHA-256 digest.
class ApiKey < ApplicationRecord
  PREFIX = 'st_'

  validates :name, presence: true

  before_validation :generate_token, on: :create

  def self.digest(token) = Digest::SHA256.hexdigest(token.to_s)

  # The active key for a token, or nil
  def self.authenticate(token)
    return if token.blank?

    find_by(token_digest: digest(token), active: true)
  end

  # Counts a request; writes last_used_at at most once a minute
  def record_use!
    attrs = { requests_count: requests_count + 1 }
    attrs[:last_used_at] = Time.current if last_used_at.nil? || last_used_at < 1.minute.ago
    update_columns(attrs)
  end

  private

  def generate_token
    self.token = "#{PREFIX}#{SecureRandom.base58(32)}"
    self.token_digest = self.class.digest(token)
    self.token_prefix = token.first(PREFIX.size + 6)
  end
end
