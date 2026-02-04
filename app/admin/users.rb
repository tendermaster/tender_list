ActiveAdmin.register User do

  # See permitted parameters documentation:
  # https://github.com/activeadmin/activeadmin/blob/master/docs/2-resource-customization.md#setting-up-strong-parameters
  #
  # Uncomment all parameters which should be permitted for assignment
  #
  permit_params :email, :name, :role, :current_plan

  index do
    selectable_column
    id_column
    column :email
    column :name
    column :role
    column :current_plan
    column :sign_in_count
    column :created_at
    actions
  end

  filter :email
  filter :name
  filter :role
  filter :current_plan
  
end
