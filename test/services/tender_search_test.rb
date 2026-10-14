require 'test_helper'

class TenderSearchTest < ActiveSupport::TestCase
  def clause(query) = TenderSearch.send(:search_clause_for, query)

  test 'typed words: most must match, across fields; an exact tender id ranks first' do
    should = clause('empanelment of agency')[:bool][:should]

    words = should.find { |c| c[:multi_match] }[:multi_match]
    assert_equal 'cross_fields', words[:type]
    assert_equal '3<75%', words[:minimum_should_match]
    assert_not_includes words[:fields], 'page_link'
    assert should.any? { |c| c.dig(:term, 'tender_id.keyword', :value) == 'empanelment of agency' }
  end

  test 'saved searches: | is OR, the words in a group must all match' do
    query = Query.new(include_keyword: 'legal service, lawyer').to_search_query

    result = clause(query)
    assert_equal '(legal service) | (lawyer)', result[:simple_query_string][:query]
    assert_equal 'and', result[:simple_query_string][:default_operator]
  end

  test 'exclusions leave tenders out instead of being OR-ed into the query' do
    query = Query.new(include_keyword: 'legal service, lawyer', exclude_keyword: 'road, office furniture').to_search_query

    result = clause(query)[:bool]
    assert_equal '(legal service) | (lawyer)', result[:must].first[:simple_query_string][:query]
    assert_equal '(road) | (office\ furniture)', result[:must_not].first[:simple_query_string][:query]
    assert_equal 'and', result[:must_not].first[:simple_query_string][:default_operator]
  end

  test 'a single -word is an exclusion' do
    result = clause('solar -road')[:bool]
    assert_equal 'solar', result[:must].first.dig(:bool, :should, 0, :multi_match, :query)
    assert_equal 'road', result[:must_not].first[:simple_query_string][:query]
  end

  test 'filters from params' do
    assert_equal({ open: false, state: nil, sort: 'relevance' }, TenderSearch.filters_from({}))
    assert_equal({ open: true, state: 'Goa', sort: 'relevance' },
                 TenderSearch.filters_from({ status: 'open', state: ' Goa ' }))
    # Closing soonest only makes sense for open tenders
    assert_equal({ open: true, state: nil, sort: 'closing' }, TenderSearch.filters_from({ sort: 'closing' }))
    assert_equal 'relevance', TenderSearch.filters_from({ sort: 'drop table' })[:sort]
    assert_not TenderSearch.filtered?(TenderSearch.filters_from({}))
    assert TenderSearch.filtered?(TenderSearch.filters_from({ state: 'Goa' }))
  end

  test 'filter clauses' do
    clauses = TenderSearch.send(:filter_clauses, { open: true, state: 'Tamil Nadu', sort: 'relevance' })
    assert_includes clauses, { term: { is_visible: true } }
    assert_includes clauses, TenderSearch::OPEN
    assert_includes clauses, { match: { state: { query: 'Tamil Nadu', operator: 'and' } } }
  end
end

class SearchPagesTest < ActionDispatch::IntegrationTest
  test 'pages past the last allowed one are not found, without searching' do
    get '/search', params: { q: 'solar', page: TenderSearch::MAX_PAGE + 1 }
    assert_response :not_found
    get '/tenders/solar-tenders', params: { page: 1800 }
    assert_response :not_found
  end
end
