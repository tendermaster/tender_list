# frozen_string_literal: true

class AddLogstashSyncIndexToTenders < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    # Composite index for Logstash JDBC polling query:
    # WHERE updated_at_auto >= :sql_last_value ORDER BY updated_at_auto ASC, id ASC
    execute <<-SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tenders_sync
      ON tenders (updated_at_auto, id);
    SQL
  end

  def down
    execute <<-SQL
      DROP INDEX CONCURRENTLY IF EXISTS idx_tenders_sync;
    SQL
  end
end
