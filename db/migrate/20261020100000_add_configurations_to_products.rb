class AddConfigurationsToProducts < ActiveRecord::Migration[8.0]
  def change
    # "Choose your requirement" cards: [{key, name, summary, attributes}]
    add_column :products, :configurations, :jsonb, null: false, default: []
    # A licensed or own photo for the page header, when there is one
    add_column :products, :image_url, :string
  end
end
