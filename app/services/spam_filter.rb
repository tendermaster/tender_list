# frozen_string_literal: true

# Spam that gets past the captcha on the public lead forms (most of it
# solved the captcha: 247 of 562 rows the old forms saved were spam).
#
# Hard rules flag on their own; none of them matched any of the 315 real
# submissions the old forms kept. Weaker signals only count in pairs
# (SOFT_LIMIT): one real name in 315 looked generated, for example.
module SpamFilter
  # Links, HTML and Russian/Chinese/Thai text: the casino, darknet and SEO spam
  PATTERN = %r{https?://|<[a-z/!]|href=|\[url|[Ѐ-ӿ一-鿿฀-๿]}i

  # A person takes longer than this to fill in a form; bots post within a second
  MIN_FILL_MS = 3_000

  # Blog-comment spam pasted into "what do you supply": "Very good post! We
  # are linking to…", "If you desire to obtain much from this paragraph…"
  COMMENT_SPAM = /\b(?:(?:good|great|nice|awesome|fantastic|wonderful) (?:post|article|blog|read|write-?up)|this (?:paragraph|post|article|blog|web ?site|weblog)|linking to|bookmark(?:ed|ing)?\b|my (?:blog|web ?site|weblog)|keep up the (?:good|great) work)/i

  # Addresses spam came from and no customer has used: Russian and
  # Belarusian domains, and throwaway services that valid_email_2 misses
  SPAM_EMAIL_DOMAINS = /(?:\.(?:ru|su|by)|@(?:fuhrenmail|bekommenmail)\.com)\z/i

  # A web address in the name field: "https://massage.example.com", "homemade.lululu.win"
  WEB_ADDRESS = %r{https?://|www\.|\b[a-z0-9-]+\.(?:com|net|org|win|xyz|ru|info|top|site|online|shop|biz|io|club|live)\b}i

  # Spam bots' made-up names: a first name with random letters stuck on,
  # one word ("DavidOrnag", "AlexSpsmedo", "Michaelskync")
  GENERATED_NAME = /\A[A-Z][a-z]{2,}(?:[A-Z][a-z]{2,}|[a-z]{3,})\z/
  COMMON_FIRST_NAMES = %w[aaron alex august brian charles daniel david edward george isiah james
                          jason john joshua kevin killian mark matthew michael paul richard robert
                          steven thomas william].freeze

  # Browser languages that no Indian tender customer has had; spam came with them
  SPAM_LANGUAGES = %w[ru uk be kk zh].freeze

  # Real answers to "what do you supply" are a few words
  ESSAY_LENGTH = 300

  SOFT_LIMIT = 2

  def self.spam?(*texts) = texts.flatten.any? { |text| text.to_s.match?(PATTERN) }

  # "x.ow.al.oro.gu.fe.1.6@gmail.com": Gmail ignores the dots, so spammers
  # vary them to look like new senders. People don't write addresses like it.
  def self.dotted_gmail?(email)
    local, domain = email.to_s.downcase.split('@', 2)
    domain.in?(%w[gmail.com googlemail.com]) && local.count('.') >= 4
  end

  def self.generated_name?(name)
    name = name.to_s.strip
    name.match?(GENERATED_NAME) && COMMON_FIRST_NAMES.any? { |first| name.downcase.start_with?(first) && name.length > first.length + 2 }
  end

  # The browser's first language, from Accept-Language ("ru-RU,ru;q=0.9" -> "ru")
  def self.language(headers) = headers.to_h['accept-language'].to_s[/\A\s*([a-z]{2})/i, 1]&.downcase

  # Why a form submission looks like spam, or nil. fill_ms is how long the
  # page was open before it was sent (lead_form_controller.js); scripts that
  # post the form directly don't send it. headers: LeadRequests#request_meta.
  def self.reason(honeypot:, fill_ms:, email:, texts:, name: nil, headers: {})
    return 'hidden field filled in' if honeypot.present?
    return 'sent without the page script' if fill_ms.blank?
    return 'sent too fast' if fill_ms.to_i < MIN_FILL_MS
    return 'links or foreign script' if spam?(texts)
    return 'dotted Gmail address' if dotted_gmail?(email)
    return 'spam email domain' if email.to_s.strip.match?(SPAM_EMAIL_DOMAINS)
    return 'web address as the name' if name.to_s.match?(WEB_ADDRESS)
    return 'blog comment spam' if Array(texts).any? { |text| text.to_s.match?(COMMENT_SPAM) }

    signals = []
    signals << 'made-up name' if generated_name?(name)
    signals << 'foreign browser language' if SPAM_LANGUAGES.include?(language(headers))
    signals << 'essay-length answer' if Array(texts).any? { |text| text.to_s.squish.length > ESSAY_LENGTH }
    signals.join(' and ') if signals.size >= SOFT_LIMIT
  end
end
