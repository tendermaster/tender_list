require 'test_helper'

class BookmarksTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: 'buyer@example.com', password: 'secret-password-1', confirmed_at: Time.current,
                         phone: '9876543210')
  end

  def tender(title, closes_in)
    Tender.create!(tender_id: "T-#{title}", title:, organisation: 'PWD', state: 'Goa', tender_source: 'goa',
                   slug_uuid: SecureRandom.uuid, submission_close_date: closes_in.from_now, updated_at_auto: Time.current)
  end

  def json = { headers: { 'Accept' => 'application/json' } }

  test 'saving and unsaving a tender' do
    road = tender('Road repair', 5.days)
    sign_in @user

    post bookmark_path(road.slug_uuid), **json
    assert_response :success
    assert_equal({ 'bookmarked' => true }, response.parsed_body)
    post bookmark_path(road.slug_uuid), **json
    assert_equal 1, @user.bookmarks.count, 'saving twice keeps one'

    delete bookmark_path(road.slug_uuid), **json
    assert_equal({ 'bookmarked' => false }, response.parsed_body)
    assert_equal 0, @user.bookmarks.count

    post bookmark_path('no-such-tender'), **json
    assert_response :not_found
  end

  test 'signed-out visitors are asked to sign in' do
    road = tender('Road repair', 5.days)
    post bookmark_path(road.slug_uuid), **json
    assert_response :unauthorized
    assert_equal 0, Bookmark.count
  end

  test 'the saved list: open first by closing date, then closed, each removable' do
    later = tender('Bridge works', 20.days)
    soon = tender('Road repair', 2.days)
    closed = tender('Old canal', -3.days)
    [later, soon, closed].each { |t| @user.bookmarks.create!(tender: t) }
    sign_in @user

    get bookmarks_path
    assert_response :success
    titles = css_select('li[data-bookmark-card] > div:first-child > a').map(&:text)
    assert_equal ['Road repair', 'Bridge works', 'Old canal'], titles
    assert_select 'li[data-bookmark-card]', text: /1 day left|2 days left/
    assert_select 'li[data-bookmark-card]', text: /Closed/
    assert_select "button[data-bookmark-url-value='#{bookmark_path(soon.slug_uuid)}'][aria-pressed=true]"
  end

  test 'an empty list says how to save tenders' do
    sign_in @user
    get bookmarks_path
    assert_select 'p', /No saved tenders yet/
  end
end
