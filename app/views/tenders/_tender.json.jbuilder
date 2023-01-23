json.extract! tender, :id, :tenderId, :title, :description, :organisation, :state, :tender_value, :submission_open_date, :submission_close_date, :attachments_id, :search_data, :created_at, :updated_at
json.url tender_url(tender, format: :json)
