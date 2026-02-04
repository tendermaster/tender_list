ActiveAdmin.register Subscription do

  # See permitted parameters documentation:
  # https://github.com/activeadmin/activeadmin/blob/master/docs/2-resource-customization.md#setting-up-strong-parameters
  #
  # Uncomment all parameters which should be permitted for assignment
  #
  permit_params :plan_name, :order_id, :price, :start_date, :end_date, :user_id, :coupon_code

  index do
    selectable_column
    id_column
    column :user
    column :plan_name
    column :start_date
    column :end_date
    column :price
    column :created_at
    actions
  end

  filter :user
  filter :plan_name, as: :select, collection: ['FREE', 'PAID', 'PREMIUM']
  filter :start_date
  filter :end_date
  filter :coupon_code

  form do |f|
    f.inputs do
      f.input :user
      f.input :plan_name, as: :select, collection: ['FREE', 'PAID', 'PREMIUM'], include_blank: false
      f.input :price
      f.input :start_date, as: :datepicker
      f.input :end_date, as: :datepicker
      f.input :coupon_code
      f.input :order_id
    end
    f.actions
  end
  
end
