class Subscription < ApplicationRecord
  validates :plan_name, inclusion: ['FREE', 'PAID', 'PREMIUM']

  def self.ransackable_attributes(auth_object = nil)
    ["coupon_code", "created_at", "end_date", "id", "order_id", "plan_name", "price", "start_date", "updated_at", "user_id"]
  end

end
