# Email is optional on lead forms (mail is off; the team calls or WhatsApps)
class AllowLeadsWithoutEmail < ActiveRecord::Migration[8.1]
  def change
    change_column_null :leads, :email, true
  end
end
