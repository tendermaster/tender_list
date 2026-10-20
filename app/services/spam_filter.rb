# frozen_string_literal: true

# Junk that gets past the captcha on the anonymous sidebar and checklist
# forms (both save to MiscDataStore): links, HTML and Russian/Chinese text.
# 247 of 562 saved rows were this before it was added.
module SpamFilter
  PATTERN = %r{https?://|<[a-z/!]|href=|\[url|[Ѐ-ӿ一-鿿฀-๿]}i

  def self.spam?(*texts) = texts.any? { |text| text.to_s.match?(PATTERN) }

  def self.indian_mobile?(number)
    phone = Phonelib.parse(number.to_s, 'IN')
    phone.valid? && phone.country == 'IN' && phone.types.intersect?(%i[mobile fixed_or_mobile])
  end
end
