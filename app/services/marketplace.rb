# products.sigmatenders.com: the catalogue (Marketplace::Catalog), the pages
# table it fills (Marketplace::PageRefresher), and the slugs, labels and
# names its pages use. These are the only place URLs and page wording are
# made: products-web reads them from the marketplace.pages view.
#
# URL shapes, one per page type, so slugs can't collide:
#   /{category}                          hub
#   /{category}/price                    price list
#   /{category}/size-chart               size and weight chart
#   /{category}/1-inch | /63mm           size (ends in -inch or mm)
#   /{category}/pe-100 | /class-b        grade (starts pe- or class-)
#   /{category}/brands/{brand}           brand
#   /{category}/manufacturers-in-{state} state
#   /{category}/dealers-in-{city}        city (whitelist below)
#   /supplier/{slug}                     supplier
module Marketplace
  # Steel tubes (IS 1239, IS 1161) call their wall classes Light, Medium and
  # Heavy, which tenders and buyers call class A, B and C
  STEEL_STANDARDS = ['IS 1239', 'IS 1161'].freeze
  STEEL_CLASSES = { 'Light' => 'A', 'Medium' => 'B', 'Heavy' => 'C' }.freeze

  # Grades that get their own page; the rest are sections of the hub
  GRADE_PAGES = %w[pe-100 pe-80 class-a class-b class-c].freeze

  # Cities with search demand (seo-research: city_volumes), each with the
  # BIS districts its makers are registered in
  CITIES = {
    'ahmedabad' => ['Ahmedabad', %w[Ahmedabad Gandhinagar]],
    'coimbatore' => ['Coimbatore', %w[Coimbatore Tiruppur]],
    'chennai' => ['Chennai', %w[Chennai Kancheepuram Kanchipuram Tiruvallur Chengalpattu]],
    'bengaluru' => ['Bengaluru', ['Bangalore', 'Bengaluru', 'Bangalore Urban', 'Bengaluru Urban', 'Bangalore Rural',
                                  'Bengaluru Rural', 'Ramanagara']],
    'pune' => ['Pune', %w[Pune]],
    'kolkata' => ['Kolkata', ['Kolkata', 'Howrah', 'North 24 Parganas', 'South 24 Parganas', 'Hooghly']],
    'mumbai' => ['Mumbai', ['Mumbai', 'Mumbai Suburban', 'Thane', 'Palghar', 'Raigad']],
    'delhi-ncr' => ['Delhi NCR', ['Delhi', 'New Delhi', 'North Delhi', 'North West Delhi', 'North East Delhi', 'West Delhi',
                                  'South Delhi', 'South West Delhi', 'East Delhi', 'Shahdara', 'Central Delhi',
                                  'Gautam Buddh Nagar', 'Ghaziabad', 'Gurugram', 'Gurgaon', 'Faridabad', 'Sonipat']],
    'raipur' => ['Raipur', %w[Raipur]],
    'hyderabad' => ['Hyderabad', ['Hyderabad', 'Rangareddy', 'Ranga Reddy', 'Medchal Malkajgiri', 'Sangareddy']],
    'indore' => ['Indore', %w[Indore Dhar]],
    'rajkot' => ['Rajkot', %w[Rajkot]],
    'guwahati' => ['Guwahati', ['Kamrup Metropolitan', 'Kamrup']],
    'madurai' => ['Madurai', %w[Madurai]],
    'jaipur' => ['Jaipur', %w[Jaipur]]
  }.freeze

  # The whitelisted city a district belongs to: [slug, name], or nil
  def self.city_for(district)
    key = district.to_s.squish.downcase
    CITIES.each { |slug, (name, districts)| return [slug, name] if districts.any? { _1.downcase == key } }
    nil
  end

  # "Supreme Industries®" => "supreme-industries"
  def self.slug(text) = text.to_s.gsub(/[®™]/, '').parameterize.presence

  # 12.5 => "12-5", 10.0 => "10"
  def self.number_slug(number) = (number.to_f == number.to_i ? number.to_i : number.to_f).to_s.tr('.', '-')

  # A spec row's size for URLs: "1-inch", "1-1-2-inch", or "63mm"
  def self.size_slug(row)
    return "#{number_slug(row['size_mm'])}mm" if row.nil? || row['inch'].blank?

    "#{row['inch'].to_s.parameterize}-inch"
  end

  # "1 inch (32 mm)" or "63 mm"
  def self.size_label(row)
    mm = "#{number_slug(row['size_mm']).tr('-', '.')} mm"
    row['inch'].present? ? "#{row['inch']} inch (#{mm})" : mm
  end

  # One slug for a grade, from a spec row ("PN 6", "PE 100", "Class B") or
  # a licence: "pn-6", "pe-100", "class-b"
  def self.grade_slug(text)
    text = text.to_s.squish
    if (pn = text[/\APN\s*-?\s*(\d+(?:\.\d+)?)\z/i, 1]) then "pn-#{number_slug(pn)}"
    elsif (pe = text[/\APE\s*-?\s*(63|80|100)\z/i, 1]) then "pe-#{pe}"
    elsif (name = text[/\A(?:class\s*-?\s*)?([1-6ABC]|light|medium|heavy)\z/i, 1]) then "class-#{name.downcase}"
    end
  end

  # "pe-100" => "PE 100", "class-b" => "Class B", "pn-12-5" => "PN 12.5"
  def self.grade_label(slug)
    kind, value = slug.to_s.split('-', 2)
    value = value.to_s.tr('-', '.')
    { 'pe' => "PE #{value}", 'pn' => "PN #{value}", 'class' => "Class #{value.upcase}" }[kind]
  end

  # The grade slugs a licence covers (Bis::VarietyParser grades); steel
  # tubes' Light/Medium/Heavy become class A/B/C
  def self.licence_grade_slugs(grades, is_number = nil)
    classes = Array(grades['classes']).map do |name|
      STEEL_STANDARDS.include?(is_number) && STEEL_CLASSES[name] ? STEEL_CLASSES[name] : name.to_s
    end
    (Array(grades['pn']).map { grade_slug("PN #{_1}") } +
      Array(grades['pe']).map { grade_slug("PE #{_1}") } +
      classes.map { grade_slug(_1) }).compact.uniq
  end

  # BIS names are upper case: "SRI MADHURA POLYMERS PVT LTD" =>
  # "Sri Madhura Polymers Pvt Ltd", keeping known abbreviations
  UPPER_WORDS = %w[LLP PVC UPVC CPVC HDPE MDPE GI MS PE PP PPR ERW SWR RCC II III IV LTD].freeze
  KEEP_AS = { 'LTD' => 'Ltd', 'UPVC' => 'uPVC' }.freeze

  def self.display_name(name)
    name.to_s.squish.split(/(\s+|-|\.|&|\()/).map do |part|
      word = part.upcase
      next KEEP_AS[word] if KEEP_AS.key?(word)
      next word if UPPER_WORDS.include?(word) || word.match?(/\A[A-Z]\z/)

      part.match?(/[a-z]/) ? part : part.capitalize
    end.join
  end
end
