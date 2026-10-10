# frozen_string_literal: true

# The scrapers looked a tender up, then inserted it if missing, three at a time
# and two jobs at once, which left 155 duplicate rows (same source and
# tender_id, consecutive ids). Merge them into the oldest row and enforce
# uniqueness, so scrapers/v2 can upsert with ON CONFLICT (tender_source,
# tender_id). No tender_id is shared between sources, and none is NULL.
class AddUniqueSourceTenderIdIndexToTenders < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    duplicate_ids = select_values(<<~SQL).map(&:to_i)
      SELECT id FROM (
        SELECT id, row_number() OVER (PARTITION BY tender_source, tender_id ORDER BY id) AS n
        FROM tenders
        WHERE (tender_source, tender_id) IN (
          SELECT tender_source, tender_id FROM tenders GROUP BY 1, 2 HAVING count(*) > 1)
      ) ranked
      WHERE n > 1
    SQL

    if duplicate_ids.any?
      transaction do
        execute <<~SQL
          CREATE TEMP TABLE tender_keepers ON COMMIT DROP AS
          SELECT d.id AS duplicate_id, k.keeper_id
          FROM tenders d
          JOIN (SELECT tender_source, tender_id, min(id) AS keeper_id FROM tenders GROUP BY 1, 2) k
            USING (tender_source, tender_id)
          WHERE d.id IN (#{duplicate_ids.join(',')})
        SQL
        # Bookmarks and attachments move to the surviving row
        execute <<~SQL
          DELETE FROM bookmarks b USING tender_keepers m
          WHERE b.tender_id = m.duplicate_id
            AND EXISTS (SELECT 1 FROM bookmarks b2 WHERE b2.tender_id = m.keeper_id AND b2.user_id = b.user_id)
        SQL
        execute 'UPDATE bookmarks b SET tender_id = m.keeper_id FROM tender_keepers m WHERE b.tender_id = m.duplicate_id'
        execute 'UPDATE attachments a SET tender_id = m.keeper_id FROM tender_keepers m WHERE a.tender_id = m.duplicate_id'
        execute "DELETE FROM tenders WHERE id IN (#{duplicate_ids.join(',')})"
      end

      # Logstash only syncs inserts and updates, so drop the deleted rows from
      # the search index too (document id = tenders.id).
      duplicate_ids.each_slice(500) do |ids|
        body = ids.map { |id| { delete: { _index: TenderSearch::ES_INDEX, _id: id } } }
        ElasticClient.bulk(body: body)
      end
      say "merged #{duplicate_ids.size} duplicate tenders"
    end

    add_index :tenders, %i[tender_source tender_id], unique: true, algorithm: :concurrently,
              name: 'index_tenders_on_tender_source_and_tender_id'
  end

  def down
    remove_index :tenders, name: 'index_tenders_on_tender_source_and_tender_id', algorithm: :concurrently
  end
end
