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

  # Status words some portals put where the winner's name goes
  NOT_A_WINNER = ['awarded', 'completed', 'closed', 'cancelled', 'under evaluation', 'retender', 'n/a', 'na', '-'].freeze

  # Who won, from whichever field the source used
  def bid_winner
    r = bid_result_hash
    name = [r['winner_name'], r['awarded_to'], dig_hash(r, 'winner', 'name')].find { |v| v.is_a?(String) && v.present? }
    seller = dig_hash(r, 'contractFullData', 'sellerOrgName').to_s.strip
    name ||= seller if seller.present? && seller.length < 80
    name.to_s.strip.presence unless NOT_A_WINNER.include?(name.to_s.strip.downcase)
  end

  def bid_contract_amount
    r = bid_result_hash
    [r['contract_amount'], r['award_value'], dig_hash(r, 'contractFullData', 'contractAmount'),
     dig_hash(r, 'winner', 'awarded_value')].find(&:present?)
  end

  def bid_evaluations?
    r = bid_result_hash
    %w[tech_eval fin_eval technical_evaluation financial_evaluation].any? { |k| r[k].is_a?(Array) && r[k].any? }
  end

  # A result worth showing: who won, the bids, or the contract value. Many
  # stored "results" (most old GeM ones, Bihar's before 2026-10-29) only
  # repeat the buyer's details or a status.
  def bid_result_details?
    bid_winner.present? || bid_contract_amount.present? || bid_evaluations?
  end

  private

  def bid_result_hash
    parsed_bid_result.is_a?(Hash) ? parsed_bid_result : {}
  end

  def dig_hash(hash, *keys)
    keys.reduce(hash) { |h, k| h.is_a?(Hash) ? h[k] : nil }
  end
end
