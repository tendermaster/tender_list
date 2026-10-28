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
    return if topic.length < 3 || topic.match?(TOPIC_GENERIC)

    topic.match?(/[a-z]/) ? topic.sub(/\A./, &:upcase) : topic.capitalize
  end
end
