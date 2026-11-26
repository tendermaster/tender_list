require 'test_helper'

# The marketplace.* views are products-web's contract (db/marketplace/views.sql).
# Changing a view without updating db/marketplace/contract.json fails here:
# then update products-web too (its types are generated from the views).
# After an intended change: bin/rails marketplace:dump_contract
class MarketplaceContractTest < ActiveSupport::TestCase
  include MarketplaceHelper

  def view(name) = ActiveRecord::Base.connection.select_all("SELECT * FROM marketplace.#{name}").to_a

  test 'the views match the contract file' do
    assert_equal JSON.parse(Marketplace::Views::CONTRACT.read), Marketplace::Views.columns
  end

  # products-web generates its quote form's Zod schema from this file
  test 'the lead request schema matches the Lead validations' do
    assert_equal JSON.parse(Marketplace::LeadSchema::FILE.read), Marketplace::LeadSchema.build,
                 'Lead validations changed: bin/rails marketplace:dump_lead_schema, then rebuild products-web'
  end

  test 'tables are unpacked into typed rows with their slugs' do
    marketplace_product(price_table: { 'rows' => [{ 'size_mm' => 63, 'inch' => '2', 'grade' => 'PN 6', 'min' => 90 }] })
    row = view('price_rows').sole
    assert_equal [63, '2-inch', 'pn-6', 90, 1], row.values_at('size_mm', 'size_slug', 'grade_slug', 'min', 'position')
  end

  test 'hidden suppliers, unclaimed phones and inactive licences never reach products-web' do
    marketplace_product
    listed = licensed_supplier('Alpha Polymers')
    listed.update!(phone: '+919000000000')
    licensed_supplier('Beta Polymers', supplier_status: :hidden)
    licensed_supplier('Gamma Polymers', status: 'Suspended')

    assert_equal ['Alpha Polymers', 'Gamma Polymers'], view('suppliers').map { _1['name'] }.sort
    assert_nil view('suppliers').find { _1['name'] == 'Alpha Polymers' }['phone']
    assert_equal [listed.id], view('licences').map { _1['supplier_id'] }

    listed.claimed!
    assert_equal '+919000000000', view('suppliers').find { _1['name'] == 'Alpha Polymers' }['phone']
  end

  test 'licence slugs and grades come through as arrays' do
    marketplace_product
    licensed_supplier('Alpha Polymers', sizes: [63, 90], pn: [6, 12.5])
    licence = view('licences').sole
    assert_equal '{exampleflow}', licence['brand_slugs']
    assert_equal '{pn-6,pn-12-5}', licence['grade_slugs']
    assert_equal '{63,90}', licence['sizes_mm']
  end
end
