require 'test_helper'

class KeywordPageTest < ActiveSupport::TestCase
  test 'keywords of several words are exact phrases; exclusions leave tenders out' do
    page = KeywordPage.create!(name: ' Ngo  Services ', include_keyword: "NGO, capacity building\nIEC (activities)",
                               exclude_keyword: 'construction of, NGO quarters')

    assert_equal 'Ngo Services', page.name
    assert_equal 'NGO, capacity building, IEC activities', page.include_keyword
    assert_equal '(NGO) | ("capacity building") | ("IEC activities") -(construction\ of) -(NGO\ quarters)',
                 page.to_search_query
    assert_equal '/tenders/Ngo-Services-tenders', page.path
  end

  test 'found by name or URL slug, ignoring case' do
    page = KeywordPage.create!(name: 'Ngo Services', include_keyword: 'NGO')
    assert_equal page, KeywordPage.for('ngo services')
    assert_equal page, KeywordPage.for('Ngo-Services')
    assert_nil KeywordPage.for('ngo')
    assert_not KeywordPage.new(name: 'NGO SERVICES', include_keyword: 'x').valid?
  end
end

class KeywordPagesTest < ActionDispatch::IntegrationTest
  # The query a search page ran, without Elasticsearch
  def searched_for(path)
    searched = nil
    original = TendersController.method(:elastic_pagy)
    TendersController.define_singleton_method(:elastic_pagy) do |query, _page, filters: {}|
      searched = query
      [Pagy.new(count: 0, page: 1, items: TenderSearch::PER_PAGE), [], false, 0]
    end
    Rails.cache.write('search:fallback_active_tenders', [])
    get path
    assert_response :success
    searched
  ensure
    TendersController.define_singleton_method(:elastic_pagy, original)
  end

  test "keyword pages use staff keywords, never a customer's saved search of the same name" do
    user = User.create!(email: 'buyer@example.com', password: 'secret-password-1', confirmed_at: Time.current)
    user.query.create!(name: 'West Bengal', include_keyword: 'Demolition tender', updates: 'NONE')
    KeywordPage.create!(name: 'Ngo Services', include_keyword: 'NGO, IEC activities')

    assert_equal 'West Bengal', searched_for('/tenders/West-Bengal-tenders')
    assert_equal '(NGO) | ("IEC activities")', searched_for('/tenders/Ngo-Services-tenders')
    assert_equal '(NGO) | ("IEC activities")', searched_for('/search?q=ngo+services')
  end
end
