# What a key may call: partners' keys only search; the products site's key
# also reads the marketplace and posts leads
class AddScopesToApiKeys < ActiveRecord::Migration[8.1]
  def change
    add_column :api_keys, :scopes, :string, array: true, null: false, default: ['search']
  end
end
