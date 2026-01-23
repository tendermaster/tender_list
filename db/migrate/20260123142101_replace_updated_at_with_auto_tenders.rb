# frozen_string_literal: true

class ReplaceUpdatedAtWithAutoTenders < ActiveRecord::Migration[7.0]
  def up
    # Remove if exists (for re-running migration)
    remove_column :tenders, :updated_at_auto if column_exists?(:tenders, :updated_at_auto)

    # 1. Add updated_at_auto with automatic trigger
    add_column :tenders, :updated_at_auto, :timestamptz, default: -> { 'NOW()' }, null: false

    # 2. Add index for Logstash polling
    add_index :tenders, :updated_at_auto

    # 3. Create trigger to auto-update on any row change
    execute <<-SQL
      CREATE OR REPLACE FUNCTION update_updated_at_auto_column()
      RETURNS TRIGGER AS $$
      BEGIN
        NEW.updated_at_auto = NOW();
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER tenders_updated_at_auto_trigger
      BEFORE UPDATE ON tenders
      FOR EACH ROW
      EXECUTE FUNCTION update_updated_at_auto_column();
    SQL
  end

  def down
    execute <<-SQL
      DROP TRIGGER IF EXISTS tenders_updated_at_auto_trigger ON tenders;
      DROP FUNCTION IF EXISTS update_updated_at_auto_column();
    SQL

    remove_column :tenders, :updated_at_auto
  end
end
