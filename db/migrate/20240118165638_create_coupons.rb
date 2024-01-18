class CreateCoupons < ActiveRecord::Migration[7.0]
  def change
    create_table :coupons do |t|
      t.text :coupon_code
      t.datetime :start_date
      t.datetime :end_date
      t.integer :validity_seconds
      t.boolean :is_valid

      t.timestamps
    end
    add_index :coupons, :coupon_code, unique: true

    add_column :subscriptions, :coupon_code, :text
    add_index :subscriptions, :coupon_code
  end
end
