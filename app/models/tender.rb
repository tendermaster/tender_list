# require 'elasticsearch/model'
class Tender < ApplicationRecord
  has_many :attachments
  has_many :bookmarks
  has_many :users, through: :bookmarks

  def self.ransackable_associations(auth_object = nil)
    ["attachments", "bookmarks", "users"]
  end

  def self.ransackable_attributes(auth_object = nil)
    ["batch_time", "bid_open_date", "created_at", "description", "emd", "full_data", "id", "is_visible", "location", "organisation", "page_link", "search_conversions", "slug", "slug_uuid", "state", "submission_close_date", "submission_open_date", "tender_category", "tender_contract_type", "tender_fee", "tender_id", "tender_reference_number", "tender_search_data", "tender_source", "tender_text_vector", "tender_value", "title", "updated_at", "text_search_trigram", "short_blog"]
  end

  def parsed_meta_data
    return {} if meta_data.blank?
    meta_data.is_a?(Hash) ? meta_data : (JSON.parse(meta_data) rescue {})
  end

  def corrigendums
    parsed_meta_data['corrigendums'] || []
  end

  def has_corrigendum?
    corrigendums.any?
  end

  def documents
    parsed_meta_data['documents'] || []
  end

  def parsed_bid_result
    return nil if bid_result.blank?
    bid_result.is_a?(Hash) ? bid_result : (JSON.parse(bid_result) rescue nil)
  end

  def has_bid_result?
    parsed_bid_result.present?
  end
end
