json.extract! query, :id, :name, :query_type, :state_name, :include_keyword, :exclude_keyword, :user_id, :created_at, :updated_at
json.url query_url(query, format: :json)
