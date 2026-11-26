module Bis
  # Reads what a licence covers from BIS's free-text "Variety": sizes (mm),
  # pressure ratings (PN), SDR, PE grade, class and type. Formats vary by
  # manufacturer ("DN 40 to 180 mm", "Nominal Size 15mm", "63 mm, 75 mm and
  # 90 mm", "NB 80"), so sizes are taken only after a size word and kept
  # only if the standard defines them; a range means the standard sizes in it.
  class VarietyParser
    SIZE_WORDS = /\b(?:DN|NB|OD|nominal\s+(?:outside\s+)?(?:size|diameter|bore)s?|size(?:\s+designation)?s?|diameter)\b/i
    # Where a size list ends: the next attribute
    STOP_WORDS = /\b(?:PN|SDR|PE\s*\d|class(?:es)?|types?|ends?|length|thickness|grades?|pressure|series|SN\s*\d|socket(?:ed)?|plain|colou?r|method)\b|[;(|]/i
    NUMBER = /\d+(?:\.\d+)?/
    RANGE = /(#{NUMBER})\s*(?:mm)?\s*(?:to|-|–|upto|up\s+to)\s*(#{NUMBER})/i

    def self.parse(text, sizes: nil) = new(text, sizes).parse

    def initialize(text, sizes)
      @text = text.to_s.gsub(/<br\s*\/?>/i, ' ').gsub(/\s+/, ' ')
      @sizes = sizes
    end

    def parse
      {
        'sizes_mm' => sizes_mm,
        'pn' => numbers_after(/\bPN\s*-?\s*(#{NUMBER})/i),
        'sdr' => numbers_after(/\bSDR\s*-?\s*(#{NUMBER})/i),
        'pe' => numbers_after(/\bPE\s*-?\s*(63|80|100)\b/i).map(&:to_i),
        'classes' => classes,
        'types' => @text.scan(/\btype\s*-?\s*([AB])\b/i).flatten.map(&:upcase).uniq.sort
      }.reject { |_, values| values.empty? }
    end

    private

    def sizes_mm
      return [] if @sizes.nil?

      found = size_segments.flat_map do |segment|
        ranges = segment.scan(RANGE).map { |low, high| (low.to_f..high.to_f) }
        singles = segment.gsub(RANGE, ' ').scan(NUMBER).map(&:to_f)
        @sizes.select { |size| ranges.any? { _1.cover?(size) } || singles.include?(size.to_f) }
      end
      found.uniq.sort
    end

    # The text after each size word, up to the next attribute
    def size_segments
      @text.to_enum(:scan, SIZE_WORDS).map do
        rest = Regexp.last_match.post_match
        rest[/\A[\s:\-–]*(.*?)(?=#{STOP_WORDS}|\z)/im, 1].to_s
      end
    end

    def numbers_after(pattern)
      @text.scan(pattern).flatten.map { |n| n.to_f == n.to_i ? n.to_i : n.to_f }.uniq.sort
    end

    # "Class 2", "Class-B"; steel tubes say Light / Medium / Heavy
    def classes
      named = @text.scan(/\bclass\s*-?\s*([1-6ABC])\b/i).flatten.map(&:upcase)
      weights = @text.scan(/\b(light|medium|heavy)\b/i).flatten.map(&:capitalize)
      (named + weights).uniq.sort
    end
  end
end
