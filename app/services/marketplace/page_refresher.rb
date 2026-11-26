module Marketplace
  # Rewrites marketplace_pages from the catalogue: every product page
  # (Marketplace::Catalog) and every supplier profile. A page's lastmod moves
  # only when its fingerprint (the data it shows) changes; pages that no
  # longer exist are deleted. Run after each BIS import and product edit.
  class PageRefresher
    def self.call = new.call

    def call
      now = Time.current
      wanted = product_pages + supplier_pages
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

    def product_pages
      Product.where(marketplace: true).flat_map do |product|
        product.catalog.pages.map { _1.merge(product_id: product.id, supplier_id: nil) }
      end
    end

    # A profile is indexable when the supplier holds an Operative licence for
    # a listed category and BIS gave a full address
    def supplier_pages
      is_numbers = Product.in_marketplace.pluck(:is_numbers).flatten.uniq
      return [] if is_numbers.empty?

      Supplier.visible.operative_for(is_numbers).includes(:bis_licences).map do |supplier|
        shown = supplier.bis_licences.select(&:operative?).sort_by(&:id)
        indexable = supplier.address.present? && supplier.pincode.present?
        state = [supplier.attributes.except('created_at', 'updated_at', 'claimed_at'),
                 shown.map { [_1.id, _1.data_changed_at&.to_i] }]
        { path: "/supplier/#{supplier.slug}", template: 'supplier', key: supplier.slug, indexable:,
          fingerprint: Digest::SHA256.hexdigest(state.to_json), product_id: nil, supplier_id: supplier.id }
      end
    end
  end
end
