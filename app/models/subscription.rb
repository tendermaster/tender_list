class Subscription < ApplicationRecord
  validates :plan_name, inclusion: ['FREE', 'PAID', 'PREMIUM']

end
