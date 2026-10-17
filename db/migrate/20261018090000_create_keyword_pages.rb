class CreateKeywordPages < ActiveRecord::Migration[8.0]
  def change
    create_table :keyword_pages do |t|
      t.string :name, null: false
      t.text :include_keyword, null: false
      t.text :exclude_keyword
      t.timestamps
    end
    add_index :keyword_pages, 'lower(name)', unique: true, name: 'index_keyword_pages_on_lower_name'
  end
end
