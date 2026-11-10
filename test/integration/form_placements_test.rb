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

  test 'an open tender leads with help filing the bid; partner and alerts in the sidebar' do
    get tender_show_path(slug_uuid: @tender.slug_uuid)
    assert_select 'h1', 'Supply of CCTV cameras'
    assert_select 'h2', 'Want us to file this bid for you?'
    assert_select 'a[href=?]', "/enquiry/bid_support?tender=#{@tender.slug_uuid}", text: 'Get help with this bid'
    assert_select "a[href^='https://wa.me/918882301033?text=']", minimum: 2
    assert_select 'h2', "Can't bid on this alone?"
    assert_select '#relevant_tenders_form form input[name=fill_ms]'
    assert_select '#relevant_tenders_form input[name=tender][value=?]', @tender.slug_uuid
    # The bid help comes before the details
    assert_operator response.body.index('Want us to file this bid'), :<, response.body.index('Tender details')
  end

  test 'visitors sign in to see an open tender\'s ID and link; signed-in users see them' do
    @tender.update!(page_link: 'https://eprocure.goa.gov.in/t/1')
    get tender_show_path(slug_uuid: @tender.slug_uuid)
    assert_select 'a[href=?]', new_user_session_path, text: /Sign in free for the tender ID and link/
    assert_not_includes response.body, 'eprocure.goa.gov.in'
    assert_not_includes response.body, '>T-1<'

    sign_in User.create!(email: 'free@example.com', password: 'secret-password-1', confirmed_at: Time.current)
    get tender_show_path(slug_uuid: @tender.slug_uuid)
    assert_select 'a[href=?]', 'https://eprocure.goa.gov.in/t/1', text: /Original notice/
    assert_select '#details dd', 'T-1'
  end

  test 'similar tenders sit under the details; the sidebar stays its own column' do
    other = Tender.create!(title: 'Installation of CCTV at schools', description: 'Supply of CCTV',
                           organisation: 'Education Dept', state: 'Goa', tender_source: 'goa', slug_uuid: SecureRandom.uuid,
                           submission_close_date: 5.days.from_now, updated_at_auto: Time.current, is_visible: true)
    stub(TenderSearch, :similar_tenders, [other]) do
      get tender_show_path(slug_uuid: @tender.slug_uuid)
    end
    assert_select '.lg\\:grid-cols-12 > .col-span-8 #similar-tenders li', 1 do
      assert_select 'h3 a', 'Installation of CCTV at schools'
      assert_select 'p', /Education Dept · Goa/
    end
    # Phones show the columns in source order: the forms come before similar tenders
    columns = css_select('.lg\\:grid-cols-12 > *').map { |el| el.name == 'aside' ? 'aside' : el['class'][/col-span-\d+/] }
    assert_equal ['col-span-8', 'aside', 'col-span-8'], columns
    assert_select '.lg\\:grid-cols-12 > aside.lg\\:row-span-2 #relevant_tenders_form'
  end

  test 'a closed tender offers alerts for new ones, not a partner' do
    @tender.update!(submission_close_date: 2.days.ago)
    get tender_show_path(slug_uuid: @tender.slug_uuid)
    assert_select 'h2', 'Bid on the next CCTV cameras tender'
    assert_select 'a[href=?]', "/enquiry/bid_support?tender=#{@tender.slug_uuid}", text: 'Get ready for the next one'
    assert_select '#relevant_tenders_form h3', 'Get tenders like this'
    # Prefilled with what the tender is for
    assert_select '#relevant_tenders_form textarea[name=sectors]', 'CCTV cameras'
    assert_select "a[href^='/find-a-partner?tender=']", count: 0
    # Closed tenders were never locked
    assert_select '#details dd', 'T-1'
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
    stub(TenderSearch, :similar_tenders, [closed, open]) do
      get tender_show_path(slug_uuid: @tender.slug_uuid)
    end
    assert_select 'p', /This tender closed on 14 Sep 2024.\s+1 tender like it is open now./
    assert_select "a[href='#relevant_tenders_form']", 'Get new ones on WhatsApp'
    assert_select "a[href='#bid-results']", count: 0
    # The open one at the top, before the details; the closed one further down
    assert_select '#similar-tenders h2', 'Open tenders like this'
    assert_select '#similar-tenders li', 1 do |items|
      assert_match(/Closes/, items.first.text)
    end
    assert_select '#more-tenders h2', 'More tenders like this'
    assert_select '#more-tenders li', 1 do |items|
      assert_match(/Closed/, items.first.text)
    end
    assert_operator response.body.index('id="similar-tenders"'), :<, response.body.index('Tender details')
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

  test 'ALL-CAPS portal text is shown in sentence case, other text as written' do
    @tender.update!(title: 'SUPPLY OF LED LIGHTS AT DISTRICT HOSPITAL', description: 'Annual CCTV maintenance for PWD offices')
    get tender_show_path(slug_uuid: @tender.slug_uuid)
    assert_select 'h1', 'Supply of led lights at district hospital'
    assert_select '#details p', 'Annual CCTV maintenance for PWD offices'
  end

  test 'an alert request from a tender page is saved with that tender' do
    post get_relevant_tenders_post_path, params: { sectors: 'CCTV', name: 'Test Person', mobile: '9876543210',
                                                   email: 'person@example.com', tender: @tender.slug_uuid, fill_ms: 10_000 }
    assert_equal @tender, Lead.order(:id).last.tender
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

  test 'a closed tender: details, then getting ready for the next one, old corrigenda last' do
    @tender.update!(title: 'Road construction at Panaji', submission_close_date: 1.year.ago,
                    meta_data: { corrigendums: [{ title: 'Date extended' }] }.to_json)
    get tender_show_path(slug_uuid: @tender.slug_uuid)
    assert_select 'h2', 'Bid on the next road construction tender'
    body = response.body
    assert_operator body.index('Tender details'), :<, body.index('Bid on the next')
    assert_operator body.index('Bid on the next'), :<, body.index('id="corrigenda"')
  end
end
