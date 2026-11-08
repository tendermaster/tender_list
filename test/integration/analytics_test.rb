require 'test_helper'

# PostHog events (ApplicationController#track): what is sent, and that
# crawlers' searches and visitors' typed answers aren't
class AnalyticsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @events = []
    @tender = Tender.create!(tender_id: 'T-1', title: 'Supply of CCTV cameras', organisation: 'PWD', state: 'Goa',
                             tender_source: 'goa', slug_uuid: SecureRandom.uuid, submission_close_date: 10.days.from_now,
                             updated_at_auto: Time.current, is_visible: true)
  end

  def capturing(&)
    stub(PostHog, :capture, ->(attrs) { @events << attrs }, &)
  end

  def search(headers: {})
    stub(TendersController, :elastic_pagy, [Pagy.new(count: 1, page: 1, items: TenderSearch::PER_PAGE), [@tender], false, 1]) do
      Rails.cache.write('search:fallback_active_tenders', [])
      get('/tenders/CCTV-tenders', headers:)
      assert_response :success
    end
  end

  test 'an enquiry is a personless event with its topic, without the answers' do
    capturing do
      post enquiry_path('callback'), params: { fill_ms: 10_000, lead: { name: 'Asha', email: 'asha@example.com', phone: '9876543210',
                                                       answers: { message: 'Call me about road tenders' } } }
    end
    assert_equal [{ event: 'enquiry_submitted', properties: { topic: 'callback', from_tender: false } }], @events
  end

  test "signed-in users' events carry their id" do
    user = User.create!(email: 'ravi@example.com', password: 'password123', name: 'Ravi', confirmed_at: Time.current)
    sign_in user
    capturing { search }
    assert_equal [['tender_search_completed', "user_#{user.id}"]], @events.map { [_1[:event], _1[:distinct_id]] }
    # Counts only, never the search words
    assert_equal %i[result_count filter_count page], @events.first[:properties].keys
    assert_equal 1, @events.first[:properties][:result_count]
  end

  test 'searches by crawlers and cookie-less clients send nothing; returning visitors do' do
    capturing do
      search(headers: { 'User-Agent' => 'Mozilla/5.0 (compatible; ClaudeBot/1.0)' })
      search
    end
    assert_empty @events

    get root_path # a visitor's first page sets the session cookie
    cookies['_sigmatenders_session'] = 'x' if cookies['_sigmatenders_session'].blank?
    capturing { search }
    assert_equal ['tender_search_completed'], @events.map { _1[:event] }
    assert_nil @events.first[:distinct_id]
  end
end
