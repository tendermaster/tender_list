# require 'elasticsearch/model'
class Tender < ApplicationRecord
  has_many :attachments
  has_many :bookmarks
  has_many :users, through: :bookmarks

  def parsed_meta_data
    @parsed_meta_data ||= begin
      return {} if meta_data.blank?
      meta_data.is_a?(Hash) ? meta_data : (JSON.parse(meta_data) rescue {})
    end
  end

  def documents
    parsed_meta_data['documents'] || []
  end

  def corrigendums
    parsed_meta_data['corrigendums'] || []
  end

  def has_corrigendum?
    parsed_meta_data['has_corrigendum'] == true || corrigendums.any?
  end

  def parsed_bid_result
    @parsed_bid_result ||= parsed_meta_data['bid_result']
  end

  def has_bid_result?
    parsed_meta_data['has_bid_result'] == true || parsed_bid_result.present?
  end
end
