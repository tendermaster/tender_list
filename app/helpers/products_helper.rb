module ProductsHelper
  SITE_NAME = 'SigmaTenders'

  def product_page_schema(product)
    url = product_url(product)
    configs = product.configuration_list
    graph = [
      { '@type' => configs.any? ? 'CollectionPage' : 'WebPage', '@id' => url, 'url' => url,
        'name' => "#{product.name}: Compare & Request a Quote",
        'description' => product.summary, 'dateModified' => product.updated_at.iso8601, 'inLanguage' => 'en-IN',
        'about' => { '@type' => 'Thing', 'name' => product.name },
        'breadcrumb' => { '@id' => "#{url}#breadcrumb" }, 'publisher' => organization_schema,
        # The "Choose your requirement" cards: sourcing briefs, so a plain list,
        # not Product markup (no real model, price or offer to describe)
        'mainEntity' => ({ '@type' => 'ItemList', 'numberOfItems' => configs.size,
                           'itemListElement' => configs.each_with_index.map do |config, index|
                             { '@type' => 'ListItem', 'position' => index + 1, 'name' => config.name,
                               'url' => "#{url}##{config.key}" }
                           end } if configs.any?) }.compact,
      { '@type' => 'BreadcrumbList', '@id' => "#{url}#breadcrumb",
        'itemListElement' => [breadcrumb_item(1, 'Products', products_url), breadcrumb_item(2, product.name, url)] }
    ]
    if product.faqs.any?
      graph << { '@type' => 'FAQPage', '@id' => "#{url}#faq", 'url' => url,
                 'mainEntity' => product.faqs.map do |question, answer|
                   { '@type' => 'Question', 'name' => question,
                     'acceptedAnswer' => { '@type' => 'Answer', 'text' => answer } }
                 end }
    end
    json_ld(graph)
  end

  def products_index_schema(products)
    url = products_url
    json_ld([
      { '@type' => 'CollectionPage', '@id' => url, 'url' => url, 'name' => 'Products: Buying Guides & Quotes',
        'inLanguage' => 'en-IN', 'publisher' => organization_schema,
        'mainEntity' => { '@type' => 'ItemList', 'numberOfItems' => products.size,
                          'itemListElement' => products.each_with_index.map do |product, index|
                            { '@type' => 'ListItem', 'position' => index + 1, 'name' => product.name,
                              'url' => product_url(product) }
                          end } }
    ])
  end

  # Open Graph and Twitter tags for a page without its own image
  def social_meta(title:, description:, url:)
    image = "#{site_base_url}/android-chrome-512x512.png"
    { og: { title:, description:, url:, type: 'website', site_name: 'Sigma Tenders', image:, locale: 'en_IN' },
      twitter: { card: 'summary', site: '@SigmaTenders', title:, description:, image: } }
  end

  private

  def json_ld(graph)
    tag.script(json_escape({ '@context' => 'https://schema.org', '@graph' => graph }.to_json).html_safe,
               type: 'application/ld+json')
  end

  def organization_schema
    { '@type' => 'Organization', 'name' => SITE_NAME, 'url' => site_base_url,
      'logo' => "#{site_base_url}/android-chrome-512x512.png" }
  end

  def breadcrumb_item(position, name, item) = { '@type' => 'ListItem', 'position' => position, 'name' => name, 'item' => item }
end
