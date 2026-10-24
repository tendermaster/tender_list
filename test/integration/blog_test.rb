require 'test_helper'

class BlogTest < ActionDispatch::IntegrationTest
  test 'a missing post is a 404 page, whatever the extension' do
    get '/blog/no-such-post'
    assert_response :not_found
    get '/blog/robots.txt'   # asked for a text 404 and got a 500
    assert_response :not_found
    assert_equal 'text/html', response.media_type
  end
end
