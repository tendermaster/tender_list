module TendersHelper
  include Pagy::Frontend

  def tender_bookmarked?(user_id, tender_id)
    if user_id.nil? || tender_id.nil?
      return false
    end

    marked = Bookmark.find_by({ user_id: user_id, tender_id: tender_id })
    if marked.present?
      true
    else
      false
    end
  end

  # Portal text for display: ALL-CAPS text in sentence case, anything else
  # as written (titleize turned "CCTV" into "Cctv")
  def tender_text(text)
    text = text.to_s.tr('_', ' ').squish
    letters = text.scan(/[[:alpha:]]/)
    return text if letters.size < 4 || letters.count { |c| c == c.upcase } < letters.size * 0.8

    text.downcase.upcase_first
  end

  # Calendar days until a portal date (IST wall-clock stored as UTC): 0 today,
  # 1 tomorrow, negative once the day has passed
  def ist_days_until(time)
    return unless time.respond_to?(:to_date)

    (time.to_date - Time.current.in_time_zone('Asia/Kolkata').to_date).to_i
  end

  # "₹99,926", "₹1.25 Lakh", or nil when the portal didn't give an amount
  def rupees(amount)
    text = currency_format(amount)
    return if text == '-'
    return "₹#{number_with_delimiter(text.to_f.round)}" if text.match?(/\A\d+(\.\d+)?\z/)

    text.match?(/\A[\d.]+ (Lakh|Crore)\z/) ? "₹#{text}" : text
  end

  # The money figures the portal gave, for the header tiles: [label, amount]
  def tender_fee_tiles(tender)
    [['Tender value', tender.tender_value], ['EMD', tender.emd], ['Tender fee', tender.tender_fee]]
      .filter_map { |label, amount| (text = rupees(amount)) && [label, text] }
  end

  # A card's heading: the title, or the description when the title is just a
  # reference number ("HPPTCL/PIU Sarabai/Tenders/SMS/2026-27/14")
  def tender_card_heading(tender)
    title = tender.title.to_s.squish
    description = tender.description.to_s.squish
    use_description = title.count('/') >= 2 && description.present? && !is_tender_id?(description)
    tender_text(use_description ? description : title)
  end

  # WhatsApp with a message naming the tender, so we know which one it's about
  def whatsapp_tender_url(tender, url)
    text = "Hi, I need help with this tender: #{tender_text(tender.title).truncate(80)} #{url}"
    "https://wa.me/918882301033?text=#{ERB::Util.url_encode(text)}"
  end

  # Boilerplate at the start of titles, before what the tender is for:
  # "E-tender for", "Rate contract for", "Supply and commissioning of", ...
  TOPIC_PREFIX = /\A(?:(?:e-?\s*)?tender\s+for|(?:annual\s+)?(?:rate|maintenance)\s+contract\s+for|
                   estimate\s+for(?:\s+the\s+work\s+of)?|rendering\s+of\s+services\s+for|
                   custom\s+bid\s+for\s+(?:services|goods)\s*-|name\s+of\s+work\s*:?|(?:the\s+)?work\s+of)\s*/ix
  TOPIC_SUPPLY = /\A(?:supply|procurement|purchase|providing|provision|provn\.?)
                  (?:,?\s*(?:and\s+)?(?:installation|commissioning|testing|fixing))*\s+of\s+/ix
  # Not a topic on their own
  TOPIC_GENERIC = /\A(?:tender|e-?tender|estimate|works?|supply|services?|goods|rate contract|misc\w*)\z/i

  # A few words saying what the tender is for, to prefill its tender alert
  # ("Structure refurbishment and painting work" from "PMJTS23015 - Structure
  # Refurbishment and Painting Work at NRPL Tikrikalan"); nil when there's
  # nothing better than a reference number or a generic word
  def tender_topic(tender)
    text = [tender.title, tender.description].map { |t| t.to_s.tr('_', ' ').squish }
                                               .find { |t| t.present? && !is_tender_id?(t) }
    return if text.blank?

    text = text.gsub(/\([^)]*\)/, ' ').sub(%r{\A[A-Z0-9/.\-]{5,}\s*[-:]\s*}, '')
    text = text.sub(TOPIC_PREFIX, '').sub(TOPIC_SUPPLY, '')
    topic = text.split(/[,;]|\s-\s|\s+(?:at|in|for|under|as per)\s+/i).first.to_s.squish.split.first(6).join(' ')
    # Cut short titles end in "..." after a part word; a cut at six words can end in "of"
    topic = topic.sub(/\s*\S*(?:\.{2,}|…)\z/, '').sub(/(?:\s+(?:of|and|to|the|with|&|on))+\z/i, '')
    return if topic.length < 3 || topic.match?(TOPIC_GENERIC) || topic.count('/') >= 2

    topic.match?(/[a-z]/) ? topic.sub(/\A./, &:upcase) : topic.capitalize
  end
end
