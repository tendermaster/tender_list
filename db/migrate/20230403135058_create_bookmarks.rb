class CreateBookmarks < ActiveRecord::Migration[7.0]
  def change
    create_table :bookmarks do |t|
      t.references :user, null: false, foreign_key: true
      t.references :tender, null: false, foreign_key: true
      t.string :personal_note
      t.timestamps
    end
  end
end
