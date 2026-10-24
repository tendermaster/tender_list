# Autovacuum last ran on tenders on 2026-08-20: at the default 20% it waits
# for ~1.2M dead rows, so the table bloated and the visibility map went stale.
# At 1% it runs about every 58k changed rows.
#
# The admin dashboard's "tenders by source this week" query read ~500 MB of
# the table for tender_source (23 s on average, up to 76 s cold). With
# tender_source in the index it reads only the index. The plain
# updated_at_auto index goes: idx_tenders_sync (updated_at_auto, id) and the
# new one cover everything it served.
class TuneTendersVacuumAndSyncIndex < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  VACUUM = 'autovacuum_vacuum_scale_factor = 0.01, autovacuum_vacuum_insert_scale_factor = 0.01, ' \
           'autovacuum_analyze_scale_factor = 0.01'

  def up
    safety_assured { execute "ALTER TABLE tenders SET (#{VACUUM})" }
    add_index :tenders, :updated_at_auto, include: :tender_source, name: 'idx_tenders_updated_at_auto_source',
                                          algorithm: :concurrently, if_not_exists: true
    remove_index :tenders, name: 'index_tenders_on_updated_at_auto', algorithm: :concurrently, if_exists: true
  end

  def down
    add_index :tenders, :updated_at_auto, name: 'index_tenders_on_updated_at_auto',
                                          algorithm: :concurrently, if_not_exists: true
    remove_index :tenders, name: 'idx_tenders_updated_at_auto_source', algorithm: :concurrently, if_exists: true
    safety_assured do
      execute 'ALTER TABLE tenders RESET (autovacuum_vacuum_scale_factor, autovacuum_vacuum_insert_scale_factor, ' \
              'autovacuum_analyze_scale_factor)'
    end
  end
end
