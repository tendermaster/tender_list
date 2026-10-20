require 'test_helper'

class ProductsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @cctv = Product.create!(name: 'CCTV Cameras', slug: 'cctv-cameras', category: 'IT & Electronics',
                            summary: 'Compare camera types and get quotes.',
                            body: "## Types\n\n- **IP cameras** — for networks\n\n<script>alert(1)</script>\n\n" \
                                  "## Frequently asked questions\n\n### How many cameras?\nSix to **ten** for an office.\n\n" \
                                  "### IP or analogue?\nIP for new sites.\n")
    Product.create!(name: 'Laptops', slug: 'laptops', category: 'IT & Electronics', summary: 'Get quotes.', body: 'x')
    Product.create!(name: 'Hidden', slug: 'hidden', category: 'Furniture', summary: 'x', body: 'x', published: false)
  end

  def quote(product = @cctv, **lead)
    post product_quote_path(product), params: { fill_ms: 10_000,
                                                lead: { quantity: '40 pieces', location: 'Pune, Maharashtra',
                                                        needed_by: 'Within a week' }.merge(lead) }
  end

  test 'the catalogue lists published products by category' do
    get products_path
    assert_response :success
    assert_select 'h2', 'IT & Electronics'
    assert_select "a[href='/products/cctv-cameras']", /CCTV Cameras/
    assert_select "a[href='/products/hidden']", count: 0

    get '/products/hidden'
    assert_response :not_found
  end

  test 'a product page shows the guide without raw HTML, and is cached for visitors' do
    get product_path(@cctv)
    assert_response :success
    assert_select 'h1', 'CCTV Cameras'
    assert_select '.prose h2', 'Types'
    assert_select '.prose script', count: 0
    assert_select 'form[action=?]', product_quote_path(@cctv)
    assert_select 'input[name=authenticity_token]', count: 0
    assert_select "a[href='/products/laptops']", 'Laptops'
    assert_includes response.headers['Cache-Control'], 's-maxage'
  end

  test 'search engines get a short title, social tags and structured data' do
    get product_path(@cctv)
    assert_select 'title', 'Sigma Tenders | CCTV Cameras: Buying Guide & Quotes'
    assert_select 'meta[property="og:url"][content=?]', 'http://www.example.com/products/cctv-cameras'
    assert_select 'meta[name="twitter:card"][content="summary"]'

    graph = JSON.parse(css_select('script[type="application/ld+json"]').first.text)['@graph']
    assert_equal %w[WebPage BreadcrumbList FAQPage], graph.map { _1['@type'] }
    assert_equal [['How many cameras?', 'Six to ten for an office.'], ['IP or analogue?', 'IP for new sites.']],
                 graph.last['mainEntity'].map { [_1['name'], _1.dig('acceptedAnswer', 'text')] }

    get products_path
    list = JSON.parse(css_select('script[type="application/ld+json"]').first.text)['@graph'].first['mainEntity']
    assert_equal ['CCTV Cameras', 'Laptops'], list['itemListElement'].map { _1['name'] }

    long = Product.new(name: 'Sanitary Napkins & Vending Machines Extra')
    assert_operator long.seo_title.size, :<=, 54
  end

  test 'a visitor asks for a quote with their name, email and mobile' do
    quote(name: 'Asha', email: 'asha@example.com', phone: '98765 43210', details: '4 MP dome')
    assert_redirected_to product_path(@cctv, quoted: 1)

    lead = Lead.last
    assert_equal [@cctv, 'Asha', 'asha@example.com', '+919876543210', '40 pieces', 'pending'],
                 [lead.product, lead.name, lead.email, lead.phone, lead.quantity, lead.status]
    assert_nil lead.user

    follow_redirect!
    assert_select 'h2', 'Request received'
  end

  test 'missing or invalid details are shown, and nothing is saved' do
    quote(name: 'Asha', email: 'not-an-email', phone: '12345', location: '')
    assert_response :unprocessable_entity
    assert_select '#alert li', /Email is invalid/
    assert_select '#alert li', /Phone is not a valid number/
    assert_select '#alert li', /Location can't be blank/
    assert_equal 0, Lead.count
  end

  test 'bots filling the hidden field are thanked but not saved' do
    post product_quote_path(@cctv), params: { website: 'spam.example', lead: { name: 'Bot' } }
    assert_redirected_to product_path(@cctv, quoted: 1)
    assert_equal 0, Lead.count
  end

  test "signed-in users quote with their account; a new mobile is kept on it" do
    user = User.create!(email: 'buyer@example.com', name: 'Ravi', password: 'secret-password-1', confirmed_at: Time.current)
    sign_in user

    get product_path(@cctv)
    assert_select 'input[name="lead[email]"]', count: 0
    assert_select 'input[name="lead[phone]"]'
    assert_includes response.headers['Cache-Control'], 'private'

    quote(email: 'someone-else@example.com', phone: '9876543210')
    lead = Lead.last
    assert_equal [user, 'Ravi', 'buyer@example.com', '+919876543210'], [lead.user, lead.name, lead.email, lead.phone]
    assert_equal '+919876543210', user.reload.phone

    get product_path(@cctv)
    assert_select 'input[name="lead[phone]"]', count: 0
  end

  test 'staff see quote requests on the dashboard and can edit products and leads' do
    lead = @cctv.leads.create!(name: 'Asha', email: 'asha@example.com', phone: '9876543210', quantity: '40', location: 'Pune')
    sign_in AdminUser.create!(email: 'admin@example.com', password: 'secret-password-1')

    get '/admin'
    assert_select 'td', '40'
    assert_select "a[href='tel:+919876543210']"
    get '/admin/leads'
    assert_response :success
    get "/admin/leads/#{lead.id}/edit"
    assert_response :success
    patch "/admin/leads/#{lead.id}", params: { lead: { status: 'called', note: 'Wants 4 MP' } }
    assert_equal 'called', lead.reload.status
    get '/admin/products'
    assert_response :success
    get "/admin/products/#{@cctv.id}/edit"
    assert_response :success
    get '/admin/keyword_pages/new'
    assert_response :success
  end
end
