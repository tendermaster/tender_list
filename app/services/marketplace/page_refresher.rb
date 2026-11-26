module Marketplace
  # Rewrites marketplace_pages from the catalogue: every product page
  # (Marketplace::Catalog) and every supplier profile. A page's lastmod moves
  # only when its fingerprint (the data it shows) changes; pages that no
  # longer exist are deleted. Run after each BIS import and product edit.
  class PageRefresher
    MIN_SUPPLIER_LICENCES = 2

    def self.call = new.call

    def call
      now = Time.current
      wanted = (product_pages + supplier_pages).uniq { _1[:path] }
      existing = MarketplacePage.all.index_by(&:path)

      MarketplacePage.transaction do
        wanted.each do |attrs|
          page = existing.delete(attrs[:path]) || MarketplacePage.new(path: attrs[:path])
          page.lastmod = now if page.new_record? || page.fingerprint != attrs[:fingerprint]
          page.assign_attributes(attrs.except(:path))
          page.save! if page.changed?
        end
        MarketplacePage.where(id: existing.values.map(&:id)).delete_all
      end
      { pages: wanted.size, indexable: wanted.count { _1[:indexable] }, removed: existing.size }
    end

    private

    def products = @products ||= Product.in_marketplace.to_a

    def product_pages
      Product.where(marketplace: true).flat_map do |product|
        product.catalog.pages.map { _1.merge(product_id: product.id, supplier_id: nil) }
      end
    end

    # Every supplier with an Operative licence in a listed category gets a
    # profile; it's indexable only with enough of its own data: 2 licences,
    # or sizes and a brand, or a claimed listing
    def supplier_pages
      by_standard = products.flat_map { |p| p.is_numbers.map { [_1, p] } }.to_h
      return [] if by_standard.empty?

      Supplier.visible.operative_for(by_standard.keys).includes(:bis_licences).map do |supplier|
        shown = supplier.bis_licences.select { _1.operative? && by_standard.key?(_1.is_number) }.sort_by(&:id)
        categories = shown.map { by_standard[_1.is_number] }.uniq
        indexable = supplier.address.present? && supplier.pincode.present? &&
                    (shown.size >= MIN_SUPPLIER_LICENCES || supplier.claimed? ||
                     (shown.any? { _1.sizes_mm.any? } && shown.any? { _1.brands.any? }))
        name = supplier.display_name.presence || supplier.name
        terms = categories.map { _1.search_term.presence || _1.name }
        place = [supplier.district, supplier.state].compact.join(', ')
        state = [supplier.attributes.except('created_at', 'updated_at', 'claimed_at'),
                 shown.map { [_1.id, _1.data_changed_at&.to_i] }, categories.map(&:slug)]
        path = "/supplier/#{supplier.slug}"
        { path:, template: 'supplier', key: supplier.slug, indexable:,
          fingerprint: Digest::SHA256.hexdigest(state.to_json),
          title: "#{name}, #{supplier.district || supplier.state}: BIS-licensed #{terms.to_sentence}",
          description: "#{name} in #{place} holds #{shown.size} BIS #{shown.size == 1 ? 'licence' : 'licences'} for " \
                       "#{terms.to_sentence}. See the standards, sizes and brands, and get a quote.",
          h1: name,
          breadcrumbs: [{ 'label' => 'Home', 'path' => '/' },
                        { 'label' => categories.first.name, 'path' => "/#{categories.first.slug}" },
                        { 'label' => name, 'path' => path }],
          data: { 'categories' => categories.map { { 'slug' => _1.slug, 'name' => _1.name } }, 'place' => place },
          product_id: nil, supplier_id: supplier.id }
      end
    end
  end
end
