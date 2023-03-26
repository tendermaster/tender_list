class CreateAttachments < ActiveRecord::Migration[7.0]
  def change
    create_table :attachments do |t|
      t.string :file_name
      t.string :file_path, index: { unique: true }
      t.string :file_text
      t.string :download_link
      t.string :download_status

      t.references :tender, null: false, foreign_key: true

      t.timestamps
    end
  end
end
