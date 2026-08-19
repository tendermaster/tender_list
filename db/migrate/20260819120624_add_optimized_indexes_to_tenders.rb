# frozen_string_literal: true

class AddOptimizedIndexesToTenders < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    # 1. State index for fast state filtering & aggregations
    execute <<-SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS index_tenders_on_state
      ON tenders (state);
    SQL

    # 2. Composite index for active state tenders
    execute <<-SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tenders_state_close_date
      ON tenders (state, submission_close_date DESC);
    SQL

    # 3. Composite index for active portal tenders
    execute <<-SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tenders_source_close_date
      ON tenders (tender_source, submission_close_date DESC);
    SQL
  end

  def down
    execute <<-SQL
      DROP INDEX CONCURRENTLY IF EXISTS index_tenders_on_state;
      DROP INDEX CONCURRENTLY IF EXISTS idx_tenders_state_close_date;
      DROP INDEX CONCURRENTLY IF EXISTS idx_tenders_source_close_date;
    SQL
  end
end
