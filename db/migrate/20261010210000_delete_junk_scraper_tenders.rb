# frozen_string_literal: true

# Rows the scrapers saved from pages they misread (fixed in scrapers/v2):
# - ireps: links on the IREPS home page ("Click Here", "User Manual for
#   Contractors") stored as tenders with a made-up closing date.
# - PSU portals (Coal India, NTPC, ...): the parser read the wrong cells, so
#   every row got an id made from its title and no closing date. The fixed
#   scraper re-adds the tenders still on those portals' home pages.
# - eprocure-cppp-gemdata without a GEM/ bid number: listing columns were read
#   off by one, giving CPPP link tokens as ids and titles as organisations.
# None of these rows are bookmarked.
class DeleteJunkScraperTenders < ActiveRecord::Migration[8.0]
  PSU_SOURCES = %w[coal_india ntpc defproc iocl delhi rajasthan punjab].freeze

  def up
    ids = select_values(<<~SQL).map(&:to_i)
      SELECT id FROM tenders
      WHERE tender_source = 'ireps'
         OR (tender_source IN (#{PSU_SOURCES.map { |s| connection.quote(s) }.join(', ')})
             AND tender_id !~ '^\\d{4}_[A-Za-z0-9]+_\\d+_\\d+$')
         OR (tender_source = 'eprocure-cppp-gemdata' AND tender_id NOT LIKE 'GEM/%')
    SQL
    return say('no junk rows') if ids.empty?

    execute "DELETE FROM bookmarks WHERE tender_id IN (#{ids.join(',')})"
    execute "DELETE FROM tenders WHERE id IN (#{ids.join(',')})" # attachments cascade

    # Logstash doesn't sync deletes to the search index (document id = tenders.id)
    ids.each_slice(500) do |slice|
      ElasticClient.bulk(body: slice.map { |id| { delete: { _index: TenderSearch::ES_INDEX, _id: id } } })
    end
    say "deleted #{ids.size} junk tenders"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
