class AddEnquiryAnswersToLeads < ActiveRecord::Migration[8.0]
  def change
    # Enquiries (/enquiry/<topic>, config/enquiry_topics.yml) replace the
    # Google Forms: the topic, and the answers keyed by question
    change_table :leads, bulk: true do |t|
      t.string :topic, index: true
      t.jsonb :answers, null: false, default: {}
    end
    change_column_null :leads, :location, true
  end
end
