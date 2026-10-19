class CreateProductsAndLeads < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      t.string :name, null: false
      t.string :slug, null: false, index: { unique: true }
      t.string :category, null: false
      t.string :summary, null: false
      t.text :body, null: false
      t.integer :position, null: false, default: 0
      t.boolean :published, null: false, default: true
      t.timestamps
    end

    create_table :leads do |t|
      t.references :product, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :name, null: false
      t.string :email, null: false
      t.string :phone, null: false
      t.string :quantity, null: false
      t.string :location, null: false
      t.string :needed_by
      t.text :details
      t.integer :status, null: false, default: 0
      t.text :note
      t.timestamps
    end
    add_index :leads, %i[status created_at]
  end
end
