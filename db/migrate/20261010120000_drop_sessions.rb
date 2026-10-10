# frozen_string_literal: true

# Sessions moved to Redis (config/initializers/session_store.rb); this table was
# last written 2025-12-03 and held 13M rows / 4.7GB.
# Backup: database/postgres_v2/backups/sessions-2026-10-10.dump (pg_restore -t sessions)
class DropSessions < ActiveRecord::Migration[7.0]
  def change
    drop_table :sessions do |t|
      t.string :session_id, null: false
      t.text :data
      t.timestamps
      t.index :session_id, unique: true
      t.index :updated_at
    end
  end
end
