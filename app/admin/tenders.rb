ActiveAdmin.register Tender do

  # See permitted parameters documentation:
  # https://github.com/activeadmin/activeadmin/blob/master/docs/2-resource-customization.md#setting-up-strong-parameters
  #
  # Uncomment all parameters which should be permitted for assignment
  #
  # permit_params :tender_id, :title, :description, :organisation, :state, :tender_value, :tender_fee, :emd, :bid_open_date, :submission_open_date, :submission_close_date, :tender_search_data, :slug, :slug_uuid, :is_visible, :page_link, :full_data, :batch_time, :search_conversions, :tender_category, :tender_contract_type, :tender_source, :tender_text_vector, :tender_reference_number, :location
  #
  # or
  #
  # permit_params do
  #   permitted = [:tender_id, :title, :description, :organisation, :state, :tender_value, :tender_fee, :emd, :bid_open_date, :submission_open_date, :submission_close_date, :tender_search_data, :slug, :slug_uuid, :is_visible, :page_link, :full_data, :batch_time, :search_conversions, :tender_category, :tender_contract_type, :tender_source, :tender_text_vector, :tender_reference_number, :location]
  #   permitted << :other if params[:action] == 'create' && current_user.admin?
  #   permitted
  # end
  
end
