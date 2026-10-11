ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Routes load lazily in tests, and Devise finds its mappings in them (mailers
# need them before any request has been made)
Rails.application.reload_routes_unless_loaded

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  # Minitest 6 dropped Object#stub (it moved to the minitest-mock gem). Same
  # use: stub(TenderSearch, :weighted_search, value_or_callable) { ... }
  def stub(object, name, value)
    original = object.method(name)
    object.define_singleton_method(name) { |*args, **kwargs| value.respond_to?(:call) ? value.call(*args, **kwargs) : value }
    yield
  ensure
    object.define_singleton_method(name, original)
  end
end

# Google ID tokens signed with a test key, checked by the real GoogleIdToken
# verification with Google's key set swapped for the test key.
module GoogleTokenHelper
  CLIENT_ID = 'test-client-id.apps.googleusercontent.com'
  KEY = OpenSSL::PKey::RSA.generate(2048)
  JWK = JWT::JWK.new(KEY, kid: 'test-key')

  def setup
    super
    @google_client_id_was = ENV['GOOGLE_CLIENT_ID']
    ENV['GOOGLE_CLIENT_ID'] = CLIENT_ID
    GoogleIdToken.singleton_class.alias_method(:real_jwks, :jwks)
    GoogleIdToken.define_singleton_method(:jwks) { |_options| JWT::JWK::Set.new(JWK) }
  end

  def teardown
    GoogleIdToken.singleton_class.alias_method(:jwks, :real_jwks)
    ENV['GOOGLE_CLIENT_ID'] = @google_client_id_was
    super
  end

  def google_token(key: KEY, **claims)
    claims = { iss: 'https://accounts.google.com', aud: CLIENT_ID, sub: 'google-123',
               email: 'person@example.com', email_verified: true, name: 'A Person',
               iat: Time.now.to_i, exp: Time.now.to_i + 3600 }.merge(claims)
    JWT.encode(claims, key, 'RS256', { kid: 'test-key' })
  end
end
