# products.sigmatenders.com: the catalogue (Marketplace::Catalog), the pages
# table it fills (Marketplace::PageRefresher) and the slugs its URLs use.
# These slugs are the only place URLs are built: products-web reads them from
# the marketplace.pages view and never builds one itself.
module Marketplace
  # "Supreme Industries®" => "supreme-industries"
  def self.slug(text) = text.to_s.gsub(/[®™]/, '').parameterize.presence

  # 12.5 => "12-5", 10.0 => "10"
  def self.number_slug(number) = (number.to_f == number.to_i ? number.to_i : number.to_f).to_s.tr('.', '-')

  # A spec row's size for URLs: "1-inch", "1-1-2-inch", or "63mm"
  def self.size_slug(row)
    return "#{number_slug(row['size_mm'])}mm" if row.nil? || row['inch'].blank?

    "#{row['inch'].to_s.parameterize}-inch"
  end

  # One slug for a grade, whether it comes from a spec row ("PN 6",
  # "Class B", "Light") or a licence: "pn-6", "class-b", "class-light"
  def self.grade_slug(text)
    text = text.to_s.squish
    if (pn = text[/\APN\s*-?\s*(\d+(?:\.\d+)?)\z/i, 1]) then "pn-#{number_slug(pn)}"
    elsif (name = text[/\A(?:class\s*-?\s*)?([1-6ABC]|light|medium|heavy)\z/i, 1]) then "class-#{name.downcase}"
    end
  end

  # The grade slugs a licence's parsed grades (Bis::VarietyParser) cover
  def self.licence_grade_slugs(grades)
    (Array(grades['pn']).map { grade_slug("PN #{_1}") } +
      Array(grades['classes']).map { grade_slug(_1.to_s) }).compact.uniq
  end
end
