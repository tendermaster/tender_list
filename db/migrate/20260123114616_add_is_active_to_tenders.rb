# frozen_string_literal: true

class AddIsActiveToTenders < ActiveRecord::Migration[7.0]
  def up
    # 1. Add is_active as a GENERATED column based on submission_close_date
    #    This is computed automatically and stays in sync
    execute <<-SQL
      ALTER TABLE tenders
      ADD COLUMN IF NOT EXISTS is_active boolean
      GENERATED ALWAYS AS (submission_close_date > NOW()) STORED;
    SQL

    # 2. Drop the old BM25 index and recreate with is_active
    execute "DROP INDEX IF EXISTS idx_tenders_search_bm25;"

    # 3. Create new BM25 index including is_active for filtering
    execute <<-SQL
      CREATE INDEX idx_tenders_search_bm25
      ON tenders
      USING bm25 (id, search_content, is_visible, is_active)
      WITH (key_field='id');
    SQL
  end

  def down
    execute "DROP INDEX IF EXISTS idx_tenders_search_bm25;"
    execute "ALTER TABLE tenders DROP COLUMN IF EXISTS is_active;"

    # Recreate original index without is_active
    execute <<-SQL
      CREATE INDEX idx_tenders_search_bm25
      ON tenders
      USING bm25 (id, search_content, is_visible, submission_close_date)
      WITH (key_field='id');
    SQL
  end
end
