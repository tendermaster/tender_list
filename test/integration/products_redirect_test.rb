require 'test_helper'

# Products moved to products.sigmatenders.com: old URLs redirect permanently
class ProductsRedirectTest < ActionDispatch::IntegrationTest
  test 'the products list and moved products keep their place on the new site' do
    get '/products'
    assert_redirected_to 'https://products.sigmatenders.com/'
    assert_response :moved_permanently

    get '/products/hdpe-pipes'
    assert_redirected_to 'https://products.sigmatenders.com/hdpe-pipes'
    assert_response :moved_permanently
  end

  test 'products the new site does not list go to its home page' do
    get '/products/cctv-cameras-recorders'
    assert_redirected_to 'https://products.sigmatenders.com/'
    post '/products/cctv-cameras-recorders/quote'
    assert_redirected_to 'https://products.sigmatenders.com/'
  end

  test 'the navigation links to the new site' do
    get '/services'
    assert_select "a[href='https://products.sigmatenders.com']"
  end
end
