module Bis
  # One row of a BIS licence report, as a Hash with the report's own keys
  # ("CML No", "Firm Name & Address", "District", "State", "Standard No",
  # "Granted Date", "Validity Date", "Current Status", "Variety", "Brand"),
  # read into the fields the importer needs.
  class Record
    def initialize(row) = @row = row.to_h

    def raw = @row

    def cml_no = @row['CML No'].to_s.strip

    def standard = @row['Standard No'].to_s.squish

    def is_number = Standards.is_number(standard)

    def status = @row['Current Status'].to_s.squish

    def variety = @row['Variety'].to_s.strip

    def granted_on = date(@row['Granted Date'])

    def valid_until = date(@row['Validity Date'])

    def district = place(@row['District'])

    def state = place(@row['State'])

    # "FIRM<BR><BR>ADDRESS:- street<BR>PINCODE:-412115"
    def name = firm_parts[0].to_s.squish.delete_prefix('M/S').delete_prefix('M/s').strip.delete_prefix('.').strip

    def address = firm_parts[1].to_s.sub(/\AADDRESS\s*:?-?\s*/i, '').squish.delete_suffix(',').presence

    def pincode = @row['Firm Name & Address'].to_s[/PIN\s*CODE\s*:?-?\s*(\d{6})/i, 1]

    # "KOHINOOR DRIP,   KOHINOOR PIPES" => ["KOHINOOR DRIP", "KOHINOOR PIPES"]
    def brands
      @row['Brand'].to_s.split(/[,;]/).map { _1.gsub(/[®™"“”]/, '').squish }.reject(&:blank?).uniq(&:downcase)
    end

    def valid? = cml_no.present? && is_number.present? && name.present?

    private

    def firm_parts
      text = @row['Firm Name & Address'].to_s.sub(/<br\s*\/?>\s*PIN\s*CODE.*\z/im, '')
      name, address = text.split(/(?:<br\s*\/?>\s*)+/i, 2)
      [name, address&.gsub(/<br\s*\/?>/i, ', ')]
    end

    # "MAHARASHTRA" => "Maharashtra", "JAMMU AND KASHMIR" => "Jammu and Kashmir"
    def place(value)
      value.to_s.squish.downcase.titleize.gsub(/\b(And|Of|The)\b/) { _1.downcase }.presence
    end

    def date(value)
      Date.iso8601(value.to_s.strip)
    rescue Date::Error
      nil
    end
  end
end
