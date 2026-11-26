require 'test_helper'

# Which products.sigmatenders.com pages exist and may be indexed
# (Marketplace::Catalog), and when their lastmod moves (PageRefresher)
class Marketplace::PageRefresherTest < ActiveSupport::TestCase
  include MarketplaceHelper

  def page(path) = MarketplacePage.find_by!(path:)

  setup do
    @product = marketplace_product(
      price_table: { 'unit' => '₹ per metre', 'rows' => [{ 'size_mm' => 63, 'grade' => 'PN 6', 'min' => 90, 'max' => 120 }] },
      spec_table: { 'rows' => [{ 'size_mm' => 63, 'inch' => '2', 'grade' => 'PN 6', 'wall_mm' => 3.8 },
                               { 'size_mm' => 90, 'grade' => 'PN 6', 'wall_mm' => 5.4 }] }
    )
    %w[Alpha Beta Gamma].each { licensed_supplier("#{_1} Polymers") }
    licensed_supplier('Delta Pipes', state: 'Gujarat')
  end

  test 'pages are indexable only with enough real data' do
    Marketplace::PageRefresher.call

    assert page('/hdpe-pipes').indexable
    assert page('/hdpe-pipes/price').indexable
    assert page('/hdpe-pipes/manufacturers/west-bengal').indexable
    assert_not page('/hdpe-pipes/manufacturers/gujarat').indexable, 'one supplier is not a list'
    assert page('/hdpe-pipes/2-inch-price').indexable, 'spec, price and 3 makers'
    assert_not page('/hdpe-pipes/90mm-price').indexable, 'no price for 90 mm'
    assert page('/hdpe-pipes/pn-6').indexable
    assert page('/hdpe-pipes/brands/exampleflow').indexable
    assert page('/supplier/alpha-polymers-kolkata').indexable
  end

  test 'lastmod moves only for pages whose data changed; gone pages are removed' do
    Marketplace::PageRefresher.call
    before = MarketplacePage.pluck(:path, :lastmod).to_h

    travel 1.day do
      Supplier.find_by!(name: 'Delta Pipes').bis_licences.update_all(status: 'Expired')
      Marketplace::PageRefresher.call
    end

    assert_nil MarketplacePage.find_by(path: '/hdpe-pipes/manufacturers/gujarat')
    assert_nil MarketplacePage.find_by(path: '/supplier/delta-pipes-kolkata')
    assert_equal before['/hdpe-pipes/manufacturers/west-bengal'], page('/hdpe-pipes/manufacturers/west-bengal').lastmod
    assert_operator page('/hdpe-pipes').lastmod, :>, before['/hdpe-pipes'], 'the hub lists one supplier fewer'
  end

  test 'a hidden supplier leaves every page' do
    Supplier.find_by!(name: 'Alpha Polymers').hidden!
    Marketplace::PageRefresher.call
    assert_not page('/hdpe-pipes/manufacturers/west-bengal').indexable
    assert_nil MarketplacePage.find_by(path: '/supplier/alpha-polymers-kolkata')
  end

  test 'one slug for a grade, from a spec row or a licence' do
    assert_equal 'pn-12-5', Marketplace.grade_slug('PN 12.5')
    assert_equal 'class-b', Marketplace.grade_slug('Class B')
    assert_equal 'class-light', Marketplace.grade_slug('Light')
    assert_equal %w[pn-6 class-light], Marketplace.licence_grade_slugs('pn' => [6], 'classes' => ['Light'])
  end

  test 'price and spec tables refuse values the views could not cast' do
    @product.spec_table = { 'rows' => [{ 'size_mm' => 63, 'wall_mm' => '3.8 mm' }] }
    assert_not @product.valid?
    assert_match(/row 1: wrong type for wall_mm/, @product.errors[:spec_table].join)
  end
end
