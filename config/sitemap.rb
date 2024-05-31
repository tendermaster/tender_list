# Set the host name for URL creation
SitemapGenerator::Sitemap.default_host = 'https://sigmatenders.com'

SitemapGenerator::Sitemap.create_index = true

SitemapGenerator::Sitemap.create(create_index: true, max_sitemap_links: 35_000) do
  # Put links creation logic here.
  #
  # The root path '/' and sitemap index file are added automatically for you.
  # Links are added to the Sitemap in the order they are specified.
  #
  # Usage: add(path, options={})
  #        (default options are used if you don't specify)
  #
  # Defaults: :priority => 0.5, :changefreq => 'weekly',
  #           :lastmod => Time.now, :host => default_host
  #
  # Examples:
  #
  # Add '/articles'
  #
  #   add articles_path, :priority => 0.7, :changefreq => 'daily'
  #
  # Add all articles:
  #
  #   Article.find_each do |article|
  #     add article_path(article), :lastmod => article.updated_at
  #   end

  # Tender.where('is_visible = true').find_each do |result|
  #   add("tender/#{result.slug}-#{result.slug_uuid}", changefreq: 'weekly')
  # end

  add '/'
  add '/about'
  add '/pricing'
  add '/free-trial'
  add how_to_file_tender_path
  add faq_path

  # add all result pages
  add tender_main_category_path, changefreq: 'weekly'
  add tender_category_by_city_path, changefreq: 'weekly'
  add tender_category_by_state_path, changefreq: 'weekly'
  add tender_category_by_sector_path, changefreq: 'daily'
  add tender_by_organisation_path, changefreq: 'daily'
  add tender_by_products_path, changefreq: 'daily'

  # result keywords search result pages
  [
    CategoryService.home_keyword_list,
    CategoryService.get_city_list,
    CategoryService.get_sector_list,
    CategoryService.get_organisation_list,
    CategoryService.get_products_list,
    CategoryService.get_state_list,
    CategoryService.get_filter_sectors
  ].flatten.each do |keyword|
    add keyword_tender_path(keyword: keyword.gsub(' ', '-')), changefreq: 'daily'
  end

  # https://developers.google.com/search/docs/crawling-indexing/large-site-managing-crawl-budget
  # https://github.com/kjvarga/sitemap_generator?tab=readme-ov-file#adding-links
  # https://stackoverflow.com/questions/20257299/sitemap-xml-should-i-prefer-lastmod-to-changefreq
  # TODO: fix updated_at 50K results and watch short_blog
  # add all tender show path
  Tender.where('is_visible = true').find_each do |tender|
    add tender_show_path(slug_uuid: tender.slug_uuid), lastmod: tender.updated_at # , changefreq: 'weekly'
  end

end
