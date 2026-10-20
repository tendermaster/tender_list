# frozen_string_literal: true

# Junk that gets past the captcha on the anonymous sidebar and checklist
# forms (both save to MiscDataStore): links, HTML and Russian/Chinese text.
# 247 of 562 saved rows were this before it was added.
module SpamFilter
  PATTERN = %r{https?://|<[a-z/!]|href=|\[url|[\u0400-\u04FF\u4E00-\u9FFF\u0E00-\u0E7F]}i

  def self.spam?(*texts) = texts.any? { |text| text.to_s.match?(PATTERN) }

  # Any country's number (foreign enquiries come in too): 7 to 15 digits,
  # not one digit repeated
  def self.plausible_phone?(number)
    digits = number.to_s.gsub(/\D/, '')
    digits.size.between?(7, 15) && digits.squeeze.size > 1
  end
end
