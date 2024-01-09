class CreateSubscriptions < ActiveRecord::Migration[7.0]
  def change
    create_table :subscriptions do |t|
      t.string :plan_name, index: true
      t.string :order_id, index: true
      t.decimal :price, precision: 12, scale: 2
      t.datetime :start_date
      t.datetime :end_date, index: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
