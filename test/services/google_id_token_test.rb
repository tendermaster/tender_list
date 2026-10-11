require 'test_helper'

class GoogleIdTokenTest < ActiveSupport::TestCase
  include GoogleTokenHelper

  test 'returns the claims of a valid token' do
    claims = GoogleIdToken.verify(google_token(sub: 'abc'))
    assert_equal 'abc', claims['sub']
    assert_equal true, claims['email_verified']
  end

  test 'rejects tokens that are not for this site, expired, from another issuer, or forged' do
    bad_tokens = {
      'other client' => google_token(aud: 'someone-else.apps.googleusercontent.com'),
      'expired' => google_token(exp: 1.minute.ago.to_i),
      'other issuer' => google_token(iss: 'https://evil.example'),
      'forged' => google_token(key: OpenSSL::PKey::RSA.generate(2048)),
      'garbage' => 'not.a.token'
    }
    bad_tokens.each do |label, token|
      assert_raises(GoogleIdToken::InvalidToken, label) { GoogleIdToken.verify(token) }
    end
  end
end
