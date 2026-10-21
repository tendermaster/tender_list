class AddTokenToApiKeys < ActiveRecord::Migration[8.1]
  def change
    # The key itself, so admins can look it up again in /admin/api_keys
    add_column :api_keys, :token, :string
  end
end
