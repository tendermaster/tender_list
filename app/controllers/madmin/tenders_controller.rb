module Madmin
  class TendersController < Madmin::ResourceController
    private

    # Exact lookups on indexed columns instead of Madmin's LIKE search, which
    # would scan the whole tenders table. Search by id, slug_uuid, tender_id or
    # reference number.
    def scoped_resources
      term = search_term.to_s.strip
      return super if term.blank?

      tenders = Tender.where(slug_uuid: term)
                      .or(Tender.where(tender_id: term))
                      .or(Tender.where(tender_reference_number: term))
      tenders = tenders.or(Tender.where(id: term.to_i)) if term.match?(/\A\d+\z/)
      tenders.reorder(sort_column => sort_direction)
    end

    # COUNT(*) over 5.6M rows took ~2s per page load; the planner's estimate is
    # instant and close enough for page numbers.
    def paginate_collection(collection)
      return super if search_term.present?

      pagy(collection, count: estimated_tender_count)
    end

    def estimated_tender_count
      Tender.connection.select_value(
        "SELECT reltuples::bigint FROM pg_class WHERE oid = 'tenders'::regclass"
      ).to_i
    end
  end
end
