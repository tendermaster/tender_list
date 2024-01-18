class Coupon < ApplicationRecord
  validates :coupon_code, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :validity_seconds, presence: true
end
