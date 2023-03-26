class CreateQueries < ActiveRecord::Migration[7.0]
  def change
    create_table :queries do |t|
      t.string :name
      t.string :query_type
      t.text :state_name
      t.text :include_keyword
      t.text :exclude_keyword
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
