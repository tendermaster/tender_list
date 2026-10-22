# Where a lead came from (LeadRequests#request_meta): IP, country, browser,
# the page with the form. For spam review and seeing which pages bring leads.
class AddRequestMetaToLeads < ActiveRecord::Migration[8.1]
  def change
    add_column :leads, :request_meta, :jsonb, null: false, default: {}
  end
end
