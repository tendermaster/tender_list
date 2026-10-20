require 'test_helper'

class TenderBreadcrumbsTest < ActionDispatch::IntegrationTest
  def breadcrumb_items(state)
    tender = Tender.create!(tender_id: "T-#{state}", title: 'Road repair', organisation: 'PWD', state:, tender_source: 'x',
                            slug_uuid: SecureRandom.uuid, submission_close_date: 5.days.from_now,
                            updated_at_auto: Time.current, is_visible: true)
    get tender_show_path(slug_uuid: tender.slug_uuid)
    graph = css_select('script[type="application/ld+json"]').map { JSON.parse(_1.text) }
                                                             .flat_map { _1['@graph'] || [_1] }
    graph.find { _1['@type'] == 'BreadcrumbList' }['itemListElement']
  end

  test "a real state's breadcrumb links to its keyword page" do
    items = breadcrumb_items('West Bengal')
    assert_equal [1, 2, 3], items.map { _1['position'] }
    assert_equal ['West Bengal Tenders', 'http://www.example.com/tenders/West-Bengal-tenders'], items[1].values_at('name', 'item')
  end

  test 'an office name in the state column is left out of the breadcrumb' do
    items = breadcrumb_items('O/O ADDL CE IMPLEMENTATION MM IRR ASSAM GHY-03')
    assert_equal ['Home', 'Road Repair'], items.map { _1['name'] }
    assert_equal [1, 2], items.map { _1['position'] }
  end

  test 'old state URLs redirect for real states and are not found otherwise' do
    get '/tenders-by-state/west-bengal'
    assert_redirected_to '/tenders/West-Bengal-tenders'
    assert_equal 301, response.status
    get '/tenders-by-state/o-o-addl-ce-implementation-mm-irr-assam-ghy-03'
    assert_response :not_found
  end
end
