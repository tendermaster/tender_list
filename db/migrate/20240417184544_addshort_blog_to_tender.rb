class AddshortBlogToTender < ActiveRecord::Migration[7.0]
  def change
    add_column :tenders, :short_blog, :text
    add_column :tenders, :meta_data, :jsonb
    add_index :tenders, :meta_data
  end
end
