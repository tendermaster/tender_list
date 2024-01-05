class CreateMiscDataStores < ActiveRecord::Migration[7.0]
  def change
    create_table :misc_data_stores do |t|
      t.json :data
      t.string :name
      t.string :source
      t.text :note

      t.timestamps
    end
  end
end
