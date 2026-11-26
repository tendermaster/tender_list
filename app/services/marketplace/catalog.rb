module Marketplace
  # What products.sigmatenders.com can show for one marketplace Product, from
  # its suppliers' Operative BIS licences and its price and spec tables, and
  # which of those pages may be indexed. Pages without enough real data
  # aren't indexable: thin pages are why most of sigmatenders.com's tender
  # URLs sit unindexed (docs/decisions.md, 2026-11-26).
  #
  # Each page carries a fingerprint of exactly the data it shows;
  # Marketplace::PageRefresher moves a page's lastmod only when that changes.
  class Catalog
    MIN_SUPPLIERS = 3 # a hub, state, size or grade page
    MIN_BRAND_LICENCES = 3

    LICENCE_COLUMNS = 'bis_licences.id, bis_licences.supplier_id, bis_licences.brands, bis_licences.grades, bis_licences.slugs, ' \
                      'bis_licences.data_changed_at, suppliers.state AS supplier_state, ' \
                      'suppliers.state_slug AS supplier_state_slug, ' \
                      'suppliers.updated_at AS supplier_updated_at'

    attr_reader :product

    def initialize(product)
      @product = product
    end

    def licences
      @licences ||= BisLicence.operative.where(is_number: product.is_numbers)
                              .joins(:supplier).merge(Supplier.visible)
                              .select(LICENCE_COLUMNS).order('bis_licences.id').to_a
    end

    def supplier_count = licences.map(&:supplier_id).uniq.size

    def listed? = product.marketplace? && product.published?

    def indexable? = listed? && supplier_count >= MIN_SUPPLIERS

    # Every page of this product, indexable or not:
    # [{ path:, template:, key:, indexable:, fingerprint: }]
    def pages
      return [] unless listed?

      base = "/#{product.slug}"
      list = [
        page(base, 'category', nil, indexable?, licences, product_state),
        page("#{base}/price", 'price', nil, indexable? && price_rows.any?, [],
             [product.price_table, product.price_updated_on]),
        page("#{base}/manufacturers", 'manufacturers', nil, indexable?, licences),
        page("#{base}/tenders", 'tenders', nil, indexable? && product.tender_query.present?, [],
             [product.tender_query, product.name])
      ]
      list.concat(state_pages(base), size_pages(base), grade_pages(base), brand_pages(base))
    end

    def price_rows = Array(product.price_table['rows'])

    def spec_rows = Array(product.spec_table['rows'])

    private

    def state_pages(base)
      licences.group_by(&:supplier_state_slug).except(nil).map do |state_slug, in_state|
        page("#{base}/manufacturers/#{state_slug}", 'state', state_slug,
             indexable? && suppliers(in_state) >= MIN_SUPPLIERS, in_state)
      end
    end

    # A size page needs its spec row and price, and 3 makers licensed for it
    def size_pages(base)
      spec_rows.group_by { _1['size_mm'].to_f }.map do |size, rows|
        makers = licences.select { |licence| licence.sizes_mm.any? { _1.to_f == size } }
        prices = price_rows.select { _1['size_mm'].to_f == size }
        page("#{base}/#{rows.first['size_slug']}-price", 'size', rows.first['size_slug'],
             indexable? && prices.any? && suppliers(makers) >= MIN_SUPPLIERS, makers, [rows, prices])
      end
    end

    # A grade page needs spec rows for the grade and 3 makers licensed for it
    def grade_pages(base)
      specified = spec_rows.group_by { _1['grade_slug'] }.except(nil)
      by_grade = licences.each_with_object(Hash.new { |h, k| h[k] = [] }) do |licence, groups|
        Array(licence.slugs['grades']).each { groups[_1] << licence }
      end
      by_grade.map do |grade, makers|
        rows = specified.fetch(grade, [])
        page("#{base}/#{grade}", 'grade', grade,
             indexable? && rows.any? && suppliers(makers) >= MIN_SUPPLIERS, makers, rows)
      end
    end

    def brand_pages(base)
      by_brand = licences.each_with_object(Hash.new { |h, k| h[k] = [] }) do |licence, groups|
        Array(licence.slugs['brands']).each { groups[_1] << licence }
      end
      by_brand.map do |slug, branded|
        page("#{base}/brands/#{slug}", 'brand', slug, indexable? && branded.size >= MIN_BRAND_LICENCES, branded)
      end
    end

    def suppliers(licences) = licences.map(&:supplier_id).uniq.size

    def product_state
      product.attributes.slice(*%w[name summary body is_numbers tender_query]).values
    end

    # The fingerprint covers the licences shown (which ones, their last
    # change, their supplier's last change) plus the page's own data
    def page(path, template, key, indexable, shown, extra = nil)
      shown_state = shown.map { [_1.id, _1.data_changed_at&.to_i, _1.supplier_updated_at&.to_i] }
      fingerprint = Digest::SHA256.hexdigest([template, key, indexable, shown_state, extra].to_json)
      { path:, template:, key: key&.to_s, indexable:, fingerprint: }
    end
  end
end
