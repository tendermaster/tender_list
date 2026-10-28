require 'test_helper'

# Where the lead forms appear on tender and search pages
class FormPlacementsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @tender = Tender.create!(tender_id: 'T-1', title: 'Supply of CCTV cameras', organisation: 'PWD', state: 'Goa',
                             tender_source: 'goa', slug_uuid: SecureRandom.uuid, submission_close_date: 10.days.from_now,
                             updated_at_auto: Time.current, is_visible: true)
  end

  # A search page showing the given tenders, without Elasticsearch
  def search(path, records)
    original = TendersController.method(:elastic_pagy)
    TendersController.define_singleton_method(:elastic_pagy) do |*|
      [Pagy.new(count: records.size, page: 1, items: TenderSearch::PER_PAGE), records, false, records.size]
    end
    Rails.cache.write('search:fallback_active_tenders', [])
    get path
    assert_response :success
  ensure
    TendersController.define_singleton_method(:elastic_pagy, original)
  end

  test 'an open tender: details first, then bidding help; partner and alerts in the sidebar' do
    get tender_show_path(slug_uuid: @tender.slug_uuid)
    assert_not_includes response.body, 'Beyond this tender'
    assert_select 'h2', 'Bidding on this tender?'
    assert_select "a[href='/enquiry/bid_support']", 'Get help filing this bid'
    assert_select 'h2', "Can't bid on this alone?"
    assert_select '#relevant_tenders_form form input[name=fill_ms]'
  end

  test 'similar tenders sit under the details; the sidebar stays its own column' do
    other = Tender.create!(title: 'Installation of CCTV at schools', description: 'Supply of CCTV',
                           organisation: 'Education Dept', state: 'Goa', tender_source: 'goa', slug_uuid: SecureRandom.uuid,
                           submission_close_date: 5.days.from_now, updated_at_auto: Time.current, is_visible: true)
    stub(TenderSearch, :similar_tenders, [other]) do
      get tender_show_path(slug_uuid: @tender.slug_uuid)
    end
    # A stray </div> once closed the details column early, squeezing these into 1/12 of the page
    assert_select '.grid-cols-12 > #similar-tenders.col-span-8 li', 1 do
      assert_select 'h3 a', 'Installation of cctv at schools'
      assert_select 'p', /Education Dept · Goa/
    end
    # Phones show the columns in source order: the forms come before similar tenders
    columns = css_select('.grid-cols-12 > div').map { |div| div['id'] || div['class'][/col-span-\d+/] }
    assert_equal ['col-span-8', 'col-span-4', 'similar-tenders'], columns
    assert_select '.grid-cols-12 > .col-span-4.lg\\:row-span-2 #relevant_tenders_form'
  end

  test 'a closed tender offers alerts for new ones, not a partner' do
    @tender.update!(submission_close_date: 2.days.ago)
    get tender_show_path(slug_uuid: @tender.slug_uuid)
    assert_select 'h2', 'Bidding on tenders like this?'
    assert_select '#relevant_tenders_form h3', 'Get alerts for tenders like this'
    # Prefilled with what the tender is for
    assert_select '#relevant_tenders_form textarea[name=sectors]', 'CCTV cameras'
    assert_select "a[href^='/find-a-partner?tender=']", count: 0
  end

  # Most search visitors land on tenders that closed long ago: the top of the
  # page points them to open ones like it
  test 'a closed tender leads with open tenders like it' do
    @tender.update!(submission_close_date: Time.zone.local(2024, 9, 14, 15))
    open = Tender.create!(title: 'Installation of CCTV at schools', organisation: 'Education Dept', state: 'Goa',
                          tender_source: 'goa', slug_uuid: SecureRandom.uuid, submission_close_date: 5.days.from_now,
                          updated_at_auto: Time.current, is_visible: true)
    closed = Tender.create!(title: 'CCTV maintenance', organisation: 'PWD', state: 'Goa', tender_source: 'goa',
                            slug_uuid: SecureRandom.uuid, submission_close_date: 1.year.ago,
                            updated_at_auto: Time.current, is_visible: true)
    stub(TenderSearch, :similar_tenders, [open, closed]) do
      get tender_show_path(slug_uuid: @tender.slug_uuid)
    end
    assert_select 'p', /This tender closed on 14 Sep 2024.\s+1 tender like it is open now./
    assert_select "a[href='#similar-tenders']", 'See open tenders like this'
    assert_select "a[href='#relevant_tenders_form']", 'Get alerts for new ones'
    assert_select "a[href='#bid-results']", count: 0
    assert_select '#similar-tenders h2', 'Open tenders like this'
    assert_select '#similar-tenders li', 2 do |items|
      assert_match(/Closes/, items.first.text)
      assert_match(/Closed/, items.last.text)
    end
  end

  test 'a closed tender links to its bid result only when there is one' do
    @tender.update!(submission_close_date: 1.year.ago,
                    meta_data: { has_bid_result: true, bid_result: { status: 'active', bid_data: { 'Name' => 'A Buyer' } } }.to_json)
    get tender_show_path(slug_uuid: @tender.slug_uuid)
    assert_select "a[href='#bid-results']", count: 0
    assert_select '#bid-results', count: 0

    @tender.update!(meta_data: { has_bid_result: true, bid_result: { winner_name: 'Acme Traders', contract_amount: '120000' } }.to_json)
    get tender_show_path(slug_uuid: @tender.slug_uuid)
    assert_select "a[href='#bid-results']", 'See who won'
    assert_select '#bid-results', /Acme Traders/
  end

  test 'an open tender has no closed banner' do
    get tender_show_path(slug_uuid: @tender.slug_uuid)
    assert_not_includes response.body, 'This tender closed on'
  end

  test 'search results: alerts for the search come first in the sidebar' do
    search('/tenders/CCTV-tenders', [@tender])
    assert_select '#relevant_tenders_form h3', 'Get new CCTV tenders'
    assert_select '#relevant_tenders_form textarea[name=sectors]', 'CCTV'
    assert_select '#relevant_tenders_form', count: 1
  end

  test 'no results: one alerts box, in the results' do
    search('/tenders/Hovercraft-tenders', [])
    assert_select '#relevant_tenders_form', count: 1
    assert_select '#relevant_tenders_form h3', /No live tenders matching “Hovercraft” today/
  end

  test 'signed-in users are offered to save the search as an alert' do
    sign_in User.create!(email: 'buyer@example.com', password: 'secret-password-1', confirmed_at: Time.current,
                         phone: '9876543210')
    search('/tenders/CCTV-tenders', [@tender])
    assert_select '#relevant_tenders_form form', count: 0
    assert_select 'a[href=?]', new_query_path(keyword: 'CCTV'), 'Save “CCTV” as an alert'

    get new_query_path(keyword: 'CCTV')
    assert_select 'textarea[name="query[include_keyword]"]', 'CCTV'
  end
end
