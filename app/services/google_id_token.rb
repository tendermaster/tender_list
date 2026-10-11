# Verifies the ID token (a JWT signed by Google) that Google Identity Services
# hands the page after One Tap or the "Sign in with Google" button.
# https://developers.google.com/identity/gsi/web/guides/verify-google-id-token
class GoogleIdToken
  class InvalidToken < StandardError; end

  CERTS_URL = URI('https://www.googleapis.com/oauth2/v3/certs')
  ISSUERS = ['accounts.google.com', 'https://accounts.google.com'].freeze

  # @return [Hash] the token's claims: sub, email, email_verified, name, ...
  def self.verify(token, client_id: ENV.fetch('GOOGLE_CLIENT_ID'))
    claims, = JWT.decode(token.to_s, nil, true,
                         algorithms: ['RS256'], jwks: method(:jwks),
                         iss: ISSUERS, verify_iss: true,
                         aud: client_id, verify_aud: true)
    claims
  rescue JWT::DecodeError => e
    raise InvalidToken, e.message
  end

  # Google rotates its signing keys every few days; refetch when a token names
  # a key we haven't seen, at most every 5 minutes so forged tokens can't make
  # every request fetch.
  def self.jwks(options)
    if options[:kid_not_found] && !Rails.cache.exist?('google_oauth2_certs_recent')
      Rails.cache.delete('google_oauth2_certs')
    end
    keys = Rails.cache.fetch('google_oauth2_certs', expires_in: 6.hours) do
      Rails.cache.write('google_oauth2_certs_recent', true, expires_in: 5.minutes)
      response = Net::HTTP.get_response(CERTS_URL)
      raise InvalidToken, "fetching Google certs: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end
    JWT::JWK::Set.new(keys)
  end
end
