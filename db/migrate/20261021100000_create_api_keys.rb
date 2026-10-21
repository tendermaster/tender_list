class CreateApiKeys < ActiveRecord::Migration[8.1]
  def change
    # Keys for /api/v1/search, one per partner; only a digest of each is stored
    create_table :api_keys do |t|
      t.string :name, null: false
      t.string :token_digest, null: false, index: { unique: true }
      t.string :token_prefix, null: false
      t.boolean :active, null: false, default: true
      t.datetime :last_used_at
      t.integer :requests_count, null: false, default: 0
      t.timestamps
    end
  end
end
