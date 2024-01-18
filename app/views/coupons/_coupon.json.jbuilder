json.extract! coupon, :id, :coupon_code, :start_date, :end_date, :validity_seconds, :is_valid, :created_at, :updated_at
json.url coupon_url(coupon, format: :json)
