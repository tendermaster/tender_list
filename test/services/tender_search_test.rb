require 'test_helper'

class TenderSearchTest < ActiveSupport::TestCase
  def clause(query) = TenderSearch.send(:search_clause_for, query)

  test 'exclusions leave tenders out instead of being OR-ed into the query' do
    query = Query.new(include_keyword: 'legal service, lawyer', exclude_keyword: 'road, office furniture').to_search_query

    result = clause(query)[:bool]
    assert_equal '(legal service) | (lawyer)', result[:must].first[:simple_query_string][:query]
    assert_equal '(road) | (office\ furniture)', result[:must_not].first[:simple_query_string][:query]
  end

  test 'a plain search is unchanged, and a single -word is an exclusion' do
    assert_equal 'solar pump', clause('solar pump')[:multi_match][:query]
    assert_equal 'non-woven bags', clause('non-woven bags')[:multi_match][:query]

    result = clause('solar -road')[:bool]
    assert_equal 'solar', result[:must].first[:multi_match][:query]
    assert_equal 'road', result[:must_not].first[:simple_query_string][:query]
  end
end
