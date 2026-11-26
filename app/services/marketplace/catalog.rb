module Marketplace
  # What products.sigmatenders.com shows for one marketplace Product, from its
  # suppliers' Operative BIS licences and its price and spec tables: which
  # pages exist, which may be indexed, and what each says about itself
  # (title, description, h1, breadcrumbs, template data). Thin pages are why
  # most of sigmatenders.com's tender URLs sit unindexed, so a page is
  # indexable only with enough real data (docs/decisions.md, 2026-11-26).
  #
  # Each page carries a fingerprint of exactly the data it shows;
  # Marketplace::PageRefresher moves its lastmod only when that changes.
  class Catalog
    # Gates (set against the full BIS import; see docs/decisions.md)
    MIN_HUB_MAKERS = 10
    MIN_STATE_MAKERS = 5
    MIN_CITY_MAKERS = 8
    MIN_SIZE_MAKERS = 3
    MIN_GRADE_MAKERS = 5
    MIN_BRAND_LICENCES = 3

    LICENCE_COLUMNS = 'bis_licences.id, bis_licences.supplier_id, bis_licences.is_number, bis_licences.brands, ' \
                      'bis_licences.grades, bis_licences.slugs, bis_licences.data_changed_at, ' \
                      'suppliers.state AS supplier_state, suppliers.state_slug AS supplier_state_slug, ' \
                      'suppliers.district AS supplier_district, suppliers.updated_at AS supplier_updated_at'

    attr_reader :product

    def initialize(product)
      @product = product
    end

    def licences
      @licences ||= BisLicence.operative.where(is_number: product.is_numbers)
                              .joins(:supplier).merge(Supplier.visible)
                              .select(LICENCE_COLUMNS).order('bis_licences.id').to_a
    end

    def makers(list = licences) = list.map(&:supplier_id).uniq.size

    def listed? = product.marketplace? && product.published?

    def indexable? = listed? && makers >= MIN_HUB_MAKERS && product.body.present?

    def price_rows = Array(product.price_table['rows'])

    def spec_rows = Array(product.spec_table['rows'])

    # Every page of this product: [{ path:, template:, key:, indexable:,
    # fingerprint:, title:, description:, h1:, breadcrumbs:, data: }]
    def pages
      return [] unless listed?

      @state_pages = state_pages
      list = [*@state_pages, *city_pages, *size_pages, *grade_pages, *brand_pages, price_page, size_chart_page]
      [hub_page, *list.compact]
    end

    private

    def name = product.name

    # "HDPE pipe": how buyers search for it
    def term = product.search_term.presence || name

    def base = "/#{product.slug}"

    def crumbs(*extra) = [['Home', '/'], [name, base], *extra]

    def month(date) = date&.strftime('%B %Y')

    def hub_page
      states = (@state_pages || []).map do |page|
        { 'name' => page[:data]['state'], 'makers' => page[:data]['makers'], 'path' => page[:indexable] ? page[:path] : nil }
      end
      grades = grade_groups.map do |slug, group|
        { 'slug' => slug, 'label' => Marketplace.grade_label(slug), 'makers' => makers(group) }
      end
      sizes = size_groups.map { |mm, group| { 'mm' => mm, 'makers' => makers(group) } }
      count = makers
      page(base, 'category', nil, indexable?, licences, product_state,
           title: "#{name}: BIS-licensed manufacturers, sizes and prices",
           description: count.positive? ? "Compare #{count} BIS-licensed #{term} manufacturers in #{states.size} states, " \
                                          "with the sizes and grades each is licensed for. Get quotes within 48 hours." : product.summary,
           h1: name, breadcrumbs: [['Home', '/'], [name, base]],
           data: { 'makers' => count, 'states' => states, 'grades' => grades, 'sizes' => sizes,
                   'standards' => product.is_numbers, 'faqs' => product.faqs, 'term' => term })
    end

    def price_page
      return if price_rows.empty?

      title = "#{term.upcase_first} price list, #{month(product.price_updated_on)}"
      page("#{base}/price", 'price', nil, indexable?, [], [product.price_table, product.price_updated_on],
           title:, h1: title, breadcrumbs: crumbs(['Price list', "#{base}/price"]),
           description: "#{term.upcase_first} prices by size, class and brand, updated #{month(product.price_updated_on)}. " \
                        'Get current quotes from BIS-licensed makers.',
           data: { 'term' => term })
    end

    def size_chart_page
      return if spec_rows.empty?

      title = "#{term.upcase_first} size and weight chart"
      page("#{base}/size-chart", 'size-chart', nil, indexable?, [], product.spec_table,
           title:, h1: title, breadcrumbs: crumbs(['Size and weight chart', "#{base}/size-chart"]),
           description: "Outside diameter, wall thickness and weight per metre of #{term}s by size and grade, " \
                        "as #{product.spec_table['standard'].presence || product.is_numbers.first} sets them.",
           data: { 'term' => term })
    end

    def state_pages
      licences.group_by(&:supplier_state_slug).except(nil).map do |state_slug, group|
        state = group.first.supplier_state
        count = makers(group)
        page("#{base}/manufacturers-in-#{state_slug}", 'state', state_slug,
             indexable? && count >= MIN_STATE_MAKERS, group,
             title: "#{term.upcase_first} manufacturers in #{state}",
             h1: "#{term.upcase_first} manufacturers in #{state}",
             description: "#{count} BIS-licensed #{term} #{count == 1 ? 'manufacturer' : 'manufacturers'} in #{state}, " \
                          'with their licences, sizes and brands. Get quotes from makers near you.',
             breadcrumbs: crumbs([state, "#{base}/manufacturers-in-#{state_slug}"]),
             data: { 'state' => state, 'makers' => count, 'term' => term })
      end
    end

    def city_pages
      licences.group_by { Marketplace.city_for(_1.supplier_district) }.except(nil).map do |(city_slug, city), group|
        count = makers(group)
        page("#{base}/dealers-in-#{city_slug}", 'city', city_slug, indexable? && count >= MIN_CITY_MAKERS, group,
             title: "#{term.upcase_first} dealers and manufacturers in #{city}",
             h1: "#{term.upcase_first} manufacturers in and around #{city}",
             description: "#{count} BIS-licensed #{term} manufacturers in and around #{city}, " \
                          'with their licences, sizes and brands. Get quotes within 48 hours.',
             breadcrumbs: crumbs([city, "#{base}/dealers-in-#{city_slug}"]),
             data: { 'city' => city, 'districts' => Marketplace::CITIES[city_slug].last, 'makers' => count, 'term' => term })
      end
    end

    # A page per size in the spec table; indexable with 3 makers licensed for it
    def size_pages
      spec_rows.group_by { _1['size_mm'].to_f }.map do |size, rows|
        row = rows.first
        group = licences.select { |licence| licence.sizes_mm.any? { _1.to_f == size } }
        prices = price_rows.select { _1['size_mm'].to_f == size }
        label = Marketplace.size_label(row)
        path = "#{base}/#{row['size_slug']}"
        page(path, 'size', row['size_slug'], indexable? && makers(group) >= MIN_SIZE_MAKERS, group, [rows, prices],
             title: "#{term.upcase_first} #{label}: #{prices.any? ? 'price, ' : ''}specifications and makers",
             h1: "#{name} #{label}",
             description: "#{label} #{term}: #{prices.any? ? 'current price range, ' : ''}wall thickness and weight by " \
                          "grade, and #{makers(group)} BIS-licensed makers of this size.",
             breadcrumbs: crumbs([label, path]),
             data: { 'size_mm' => size, 'label' => label, 'makers' => makers(group), 'term' => term })
      end
    end

    # Only PE 100, PE 80 and class A/B/C get pages; other grades are hub sections
    def grade_pages
      grade_groups.slice(*GRADE_PAGES).map do |slug, group|
        label = Marketplace.grade_label(slug)
        path = "#{base}/#{slug}"
        page(path, 'grade', slug, indexable? && makers(group) >= MIN_GRADE_MAKERS, group,
             spec_rows.select { _1['grade_slug'] == slug },
             title: "#{term.upcase_first} #{label}: manufacturers and specifications",
             h1: "#{name} #{label}",
             description: "#{makers(group)} BIS-licensed makers of #{label} #{term}s, with the sizes each is licensed " \
                          'for. Get quotes within 48 hours.',
             breadcrumbs: crumbs([label, path]),
             data: { 'grade' => slug, 'label' => label, 'makers' => makers(group), 'term' => term })
      end
    end

    def brand_pages
      by_brand = licences.each_with_object(Hash.new { |h, k| h[k] = [] }) do |licence, groups|
        Array(licence.slugs['brands']).each { groups[_1] << licence }
      end
      by_brand.map do |slug, group|
        brand = group.flat_map(&:brands).find { Marketplace.slug(_1) == slug } || slug
        path = "#{base}/brands/#{slug}"
        page(path, 'brand', slug, indexable? && group.size >= MIN_BRAND_LICENCES, group,
             title: "#{brand} #{term}: licences, sizes and prices",
             h1: "#{brand} #{name}",
             description: "#{brand} #{term}s: the BIS licences, plants and sizes behind the brand. " \
                          'Get quotes from the maker.',
             breadcrumbs: crumbs(['Brands', nil], [brand, path]),
             data: { 'brand' => brand, 'licences' => group.size, 'term' => term })
      end
    end

    def grade_groups
      @grade_groups ||= licences.each_with_object(Hash.new { |h, k| h[k] = [] }) do |licence, groups|
        Array(licence.slugs['grades']).each { groups[_1] << licence }
      end.sort_by { |slug, _| slug }.to_h
    end

    def size_groups
      @size_groups ||= licences.each_with_object(Hash.new { |h, k| h[k] = [] }) do |licence, groups|
        licence.sizes_mm.each { groups[_1] << licence }
      end.sort_by { |mm, _| mm.to_f }.to_h
    end

    def product_state
      product.attributes.slice(*%w[name summary body is_numbers tender_query search_term]).values
    end

    # The fingerprint covers the licences shown (which ones, their last
    # change, their supplier's last change), the page's own data and copy
    def page(path, template, key, indexable, shown, extra = nil, **copy)
      shown_state = shown.map { [_1.id, _1.data_changed_at&.to_i, _1.supplier_updated_at&.to_i] }
      fingerprint = Digest::SHA256.hexdigest([template, key, indexable, shown_state, extra, copy].to_json)
      { path:, template:, key: key&.to_s, indexable:, fingerprint:,
        title: copy[:title], description: copy[:description], h1: copy[:h1],
        breadcrumbs: copy[:breadcrumbs].map { |label, href| { 'label' => label, 'path' => href } },
        data: copy[:data] }
    end
  end
end
