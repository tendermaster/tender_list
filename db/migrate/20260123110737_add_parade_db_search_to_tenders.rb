# frozen_string_literal: true

class AddParadeDbSearchToTenders < ActiveRecord::Migration[7.0]
  def up
    # 1. Add generated search_content column (combines title, description, organisation)
    #    Title is repeated for boosting effect
    execute <<-SQL
      ALTER TABLE tenders
      ADD COLUMN IF NOT EXISTS search_content text
      GENERATED ALWAYS AS (
        COALESCE(title, '') || ' ' ||
        COALESCE(title, '') || ' ' ||
        COALESCE(description, '') || ' ' ||
        COALESCE(organisation, '') || ' ' ||
        COALESCE(state, '')
      ) STORED;
    SQL

    # 2. Create ParadeDB BM25 index on the search column
    #    key_field='id' is required for pdb.score(id) to work
    execute <<-SQL
      CREATE INDEX IF NOT EXISTS idx_tenders_search_bm25
      ON tenders
      USING bm25 (id, search_content, is_visible, submission_close_date)
      WITH (key_field='id');
    SQL
  end

  def down
    execute "DROP INDEX IF EXISTS idx_tenders_search_bm25;"
    execute "ALTER TABLE tenders DROP COLUMN IF EXISTS search_content;"
  end
end
