# Bot check on public forms: Cloudflare Turnstile (usually invisible) when
# TURNSTILE_SITE_KEY and TURNSTILE_SECRET_KEY are set, reCAPTCHA v2 otherwise.
# The view side is ApplicationHelper#captcha_tags.
module Captcha
  VERIFY_URL = URI('https://challenges.cloudflare.com/turnstile/v0/siteverify')

  def self.turnstile?
    ENV['TURNSTILE_SITE_KEY'].present? && ENV['TURNSTILE_SECRET_KEY'].present?
  end

  private

  def verify_captcha = captcha_failure.nil?

  # Why the captcha wasn't passed ('missing token', Turnstile's error codes),
  # or nil when it was
  def captcha_failure
    return (verify_recaptcha ? nil : 'recaptcha failed') unless Captcha.turnstile?

    token = params['cf-turnstile-response'].to_s
    return 'missing token' if token.blank?

    response = Net::HTTP.start(VERIFY_URL.host, VERIFY_URL.port, use_ssl: true, open_timeout: 5, read_timeout: 5) do |http|
      http.post(VERIFY_URL.path, URI.encode_www_form(secret: ENV['TURNSTILE_SECRET_KEY'], response: token,
                                                     remoteip: request.remote_ip))
    end
    result = JSON.parse(response.body)
    return if result['success'] == true

    Array(result['error-codes']).join(', ').presence || 'not passed'
  rescue StandardError => e
    Rails.logger.warn("Turnstile verification failed: #{e.class}: #{e.message}")
    "verification error (#{e.class})"
  end
end
