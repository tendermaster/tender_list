class CreatePgTextsearchIndexes < ActiveRecord::Migration[7.0]
  def up
    # Enable pg_textsearch extension
    execute "CREATE EXTENSION IF NOT EXISTS pg_textsearch;"

    # Title: short text → moderate k1, low b
    execute <<-SQL
      CREATE INDEX idx_tenders_title_bm25
      ON tenders
      USING bm25(title)
      WITH (text_config = 'english', k1 = 1.4, b = 0.7);
    SQL

    # Description: longer text → higher k1 and b
    execute <<-SQL
      CREATE INDEX idx_tenders_description_bm25
      ON tenders
      USING bm25(description)
      WITH (text_config = 'english', k1 = 1.6, b = 0.85);
    SQL

    # State: very short → low b
    execute <<-SQL
      CREATE INDEX idx_tenders_state_bm25
      ON tenders
      USING bm25(state)
      WITH (text_config = 'english', k1 = 1.2, b = 0.3);
    SQL

    # Organisation: medium length
    execute <<-SQL
      CREATE INDEX idx_tenders_organisation_bm25
      ON tenders
      USING bm25(organisation)
      WITH (text_config = 'english', k1 = 1.4, b = 0.6);
    SQL
  end

  def down
    execute "DROP INDEX IF EXISTS idx_tenders_title_bm25;"
    execute "DROP INDEX IF EXISTS idx_tenders_description_bm25;"
    execute "DROP INDEX IF EXISTS idx_tenders_state_bm25;"
    execute "DROP INDEX IF EXISTS idx_tenders_organisation_bm25;"
    execute "DROP EXTENSION IF EXISTS pg_textsearch;"
  end
end
