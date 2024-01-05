# require 'elasticsearch/model'
class Tender < ApplicationRecord
  has_many :attachments
  has_many :bookmarks
  has_many :users, through: :bookmarks

  def self.ransackable_associations(auth_object = nil)
    ["attachments", "bookmarks", "users"]
  end

  def self.ransackable_attributes(auth_object = nil)
    ["batch_time", "bid_open_date", "created_at", "description", "emd", "full_data", "id", "is_visible", "location", "organisation", "page_link", "search_conversions", "slug", "slug_uuid", "state", "submission_close_date", "submission_open_date", "tender_category", "tender_contract_type", "tender_fee", "tender_id", "tender_reference_number", "tender_search_data", "tender_source", "tender_text_vector", "tender_value", "title", "updated_at"]
  end
end
