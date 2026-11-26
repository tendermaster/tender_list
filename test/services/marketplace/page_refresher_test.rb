require 'test_helper'

# Which products.sigmatenders.com pages exist and may be indexed
# (Marketplace::Catalog), what they say about themselves, and when their
# lastmod moves (PageRefresher). Made-up suppliers only.
class Marketplace::PageRefresherTest < ActiveSupport::TestCase
  include MarketplaceHelper

  def page(path) = MarketplacePage.find_by!(path:)

  setup do
    @product = marketplace_product(
      search_term: 'HDPE pipe',
      body: "## Guide\n\nText.\n\n## Frequently asked questions\n\n### Which grade?\nPE 100 for mains.\n",
      price_table: { 'unit' => '₹ per metre', 'rows' => [{ 'size_mm' => 63, 'grade' => 'PE 100', 'min' => 90, 'max' => 120 }] },
      spec_table: { 'rows' => [{ 'size_mm' => 32, 'inch' => '1', 'grade' => 'PE 100', 'wall_mm' => 3.0 },
                               { 'size_mm' => 90, 'grade' => 'PE 100', 'wall_mm' => 5.4 }] }
    )
    # 6 in West Bengal (Howrah: Kolkata), 5 in Gujarat, 1 in Kerala: 12 makers
    6.times { |i| licensed_supplier("Bengal Polymers #{i}", sizes: [32, 63], pe: [100], district: 'Howrah') }
    5.times { |i| licensed_supplier("Gujarat Pipes #{i}", state: 'Gujarat', sizes: [63], pe: [80], district: 'Rajkot') }
    licensed_supplier('Kerala Pipes', state: 'Kerala', sizes: [90])
  end

  test 'routes follow one shape per page type, and thin pages are not indexable' do
    Marketplace::PageRefresher.call

    assert page('/hdpe-pipes').indexable, '12 makers and a guide'
    assert page('/hdpe-pipes/price').indexable
    assert page('/hdpe-pipes/size-chart').indexable
    assert page('/hdpe-pipes/manufacturers-in-west-bengal').indexable
    assert page('/hdpe-pipes/manufacturers-in-gujarat').indexable, '5 makers'
    assert_not page('/hdpe-pipes/manufacturers-in-kerala').indexable, 'one maker is not a list'
    assert_not page('/hdpe-pipes/dealers-in-kolkata').indexable, 'a city page needs 8 makers'
    assert page('/hdpe-pipes/1-inch').indexable, 'spec row and 6 makers of 32 mm'
    assert_not page('/hdpe-pipes/90mm').indexable, 'one maker of 90 mm'
    assert page('/hdpe-pipes/pe-100').indexable
    assert page('/hdpe-pipes/brands/exampleflow').indexable
    assert_nil MarketplacePage.find_by(path: '/hdpe-pipes/pn-6'), 'PN grades are hub sections, not pages'
    assert_nil MarketplacePage.find_by(path: '/hdpe-pipes/manufacturers')
    assert_nil MarketplacePage.find_by(path: '/hdpe-pipes/tenders')
  end

  test 'each page carries its own title, heading, breadcrumbs and data' do
    Marketplace::PageRefresher.call

    state = page('/hdpe-pipes/manufacturers-in-west-bengal')
    assert_equal 'HDPE pipe manufacturers in West Bengal', state.title
    assert_equal [%w[Home /], ['HDPE Pipes', '/hdpe-pipes'], ['West Bengal', '/hdpe-pipes/manufacturers-in-west-bengal']],
                 state.breadcrumbs.map { _1.values_at('label', 'path') }
    assert_match(/6 BIS-licensed HDPE pipe manufacturers in West Bengal/, state.description)

    hub = page('/hdpe-pipes')
    assert_equal 12, hub.data['makers']
    assert_equal [['Which grade?', 'PE 100 for mains.']], hub.data['faqs']
    kerala = hub.data['states'].find { _1['name'] == 'Kerala' }
    assert_nil kerala['path'], 'the hub does not link to pages that are not indexable'
    assert_equal '/hdpe-pipes/manufacturers-in-gujarat', hub.data['states'].find { _1['name'] == 'Gujarat' }['path']

    assert_equal '1 inch (32 mm)', page('/hdpe-pipes/1-inch').data['label']
    assert_equal 'Bengal Polymers 0', page('/supplier/bengal-polymers-0-howrah').h1
  end

  # products-web generates Zod for page data from page-data.schema.json
  test 'every page fits the page data contract' do
    Marketplace::PageRefresher.call
    assert_equal JSON.parse(Marketplace::PageData::FILE.read), Marketplace::PageData.json_schema,
                 'shapes changed: bin/rails marketplace:dump_page_data_schema, then `just contracts` in products-web'
    assert_equal Marketplace::PageData::SHAPES.keys.sort, MarketplacePage::TEMPLATES.sort
    MarketplacePage.find_each do |page|
      problems = Marketplace::PageData.errors(page.data, template: page.template) +
                 Marketplace::PageData.errors(page.breadcrumbs, Marketplace::PageData::BREADCRUMBS, 'breadcrumbs')
      assert_empty problems, "#{page.path} (#{page.template})"
    end
    assert_equal %w[brand category city grade price size size-chart state supplier],
                 MarketplacePage.distinct.pluck(:template).sort, 'the fixture covers every template'
  end

  test 'lastmod moves only for pages whose data changed; gone pages are removed' do
    Marketplace::PageRefresher.call
    before = MarketplacePage.pluck(:path, :lastmod).to_h

    travel 1.day do
      Supplier.find_by!(name: 'Kerala Pipes').bis_licences.update_all(status: 'Expired')
      Marketplace::PageRefresher.call
    end

    assert_nil MarketplacePage.find_by(path: '/hdpe-pipes/manufacturers-in-kerala')
    assert_equal before['/hdpe-pipes/manufacturers-in-gujarat'], page('/hdpe-pipes/manufacturers-in-gujarat').lastmod
    assert_operator page('/hdpe-pipes').lastmod, :>, before['/hdpe-pipes'], 'the hub lists one maker fewer'
  end

  test 'supplier profiles are indexable only with enough of their own data' do
    thin = licensed_supplier('Thin Polymers', sizes: [], brands: [])
    Marketplace::PageRefresher.call
    assert_not page("/supplier/#{thin.slug}").indexable, 'one licence, no sizes or brand'
    assert page('/supplier/bengal-polymers-1-howrah').indexable, 'sizes and a brand'
  end

  test 'a hidden supplier leaves every page' do
    Supplier.where('name LIKE ?', 'Gujarat Pipes%').first.hidden!
    Marketplace::PageRefresher.call
    assert_not page('/hdpe-pipes/manufacturers-in-gujarat').indexable, '4 makers left'
  end

  test 'slugs and labels' do
    assert_equal 'pe-100', Marketplace.grade_slug('PE 100')
    assert_equal 'class-b', Marketplace.grade_slug('Class B')
    assert_equal %w[class-c], Marketplace.licence_grade_slugs({ 'classes' => ['Heavy'] }, 'IS 1239'),
                 'steel Heavy is class C'
    assert_equal %w[class-heavy], Marketplace.licence_grade_slugs({ 'classes' => ['Heavy'] }, 'IS 9537'),
                 'a conduit stress class is not a steel class'
    assert_equal 'PN 12.5', Marketplace.grade_label('pn-12-5')
    assert_equal ['kolkata', 'Kolkata'], Marketplace.city_for('HOWRAH')
    assert_equal 'Sri Madhura Polymers Pvt Ltd', Marketplace.display_name('SRI MADHURA POLYMERS PVT LTD')
    assert_equal 'Abc uPVC Pipes LLP', Marketplace.display_name('ABC UPVC PIPES LLP')
  end

  test 'price and spec tables refuse values the views could not cast' do
    @product.spec_table = { 'rows' => [{ 'size_mm' => 63, 'wall_mm' => '3.8 mm' }] }
    assert_not @product.valid?
    assert_match(/row 1: wrong type for wall_mm/, @product.errors[:spec_table].join)
  end
end
