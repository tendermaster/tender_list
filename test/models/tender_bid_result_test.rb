require 'test_helper'

# Which stored bid results are worth showing (shapes from real tenders)
class TenderBidResultTest < ActiveSupport::TestCase
  def tender(result)
    Tender.new(meta_data: { 'has_bid_result' => true, 'bid_result' => result }.to_json)
  end

  test 'a named winner, the bids or a contract value are a result' do
    assert_equal 'Acme Traders', tender('winner_name' => 'Acme Traders').bid_winner
    assert_equal 'Acme Traders', tender('winner' => { 'name' => 'Acme Traders' }).bid_winner
    assert_equal 'Seller Pvt Ltd', tender('contractFullData' => { 'sellerOrgName' => 'Seller Pvt Ltd' }).bid_winner
    assert tender('fin_eval' => [{ 'seller' => 'A', 'price' => 10 }]).bid_result_details?
    assert tender('status' => 'awarded', 'contract_amount' => '1512000').bid_result_details?
  end

  test "the buyer's details, a status or an empty shell are not" do
    gem_buyer = { 'status' => 'active', 'winner' => {}, 'bid_data' => { 'Name' => 'A Buyer', 'Ministry' => 'Ministry Of Health' } }
    assert_not tender(gem_buyer).bid_result_details?
    assert_nil tender(gem_buyer).bid_winner
    bihar_shell = { 'status' => 'completed', 'po_details' => '', 'awarded_date' => nil, 'contract_amount' => nil }
    assert_not tender(bihar_shell).bid_result_details?
    assert_nil tender('winner_name' => 'Awarded').bid_winner
    assert_nil tender('winner' => 'not a hash').bid_winner
    assert_not Tender.new.bid_result_details?
  end
end
