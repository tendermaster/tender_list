# frozen_string_literal: true

# Spam that gets past the captcha on the public lead forms (most of it
# solved the captcha: 247 of 562 rows the old forms saved were spam).
module SpamFilter
  # Links, HTML and Russian/Chinese/Thai text: the casino, darknet and SEO spam
  PATTERN = %r{https?://|<[a-z/!]|href=|\[url|[Ѐ-ӿ一-鿿฀-๿]}i

  # A person takes longer than this to fill in a form; bots post within a second
  MIN_FILL_MS = 3_000

  def self.spam?(*texts) = texts.flatten.any? { |text| text.to_s.match?(PATTERN) }

  # "x.ow.al.oro.gu.fe.1.6@gmail.com": Gmail ignores the dots, so spammers
  # vary them to look like new senders. People don't write addresses like it.
  def self.dotted_gmail?(email)
    local, domain = email.to_s.downcase.split('@', 2)
    domain.in?(%w[gmail.com googlemail.com]) && local.count('.') >= 4
  end

  # Why a form submission looks like spam, or nil. fill_ms is how long the
  # page was open before it was sent (lead_form_controller.js); scripts that
  # post the form directly don't send it.
  def self.reason(honeypot:, fill_ms:, email:, texts:)
    return 'hidden field filled in' if honeypot.present?
    return 'sent without the page script' if fill_ms.blank?
    return 'sent too fast' if fill_ms.to_i < MIN_FILL_MS
    return 'links or foreign script' if spam?(texts)

    'dotted Gmail address' if dotted_gmail?(email)
  end
end
