module CategoryService

  # TODO: rebuild cache before expiry, at night
  # run at 2am every day
  def self.rebuild_categories_cache
    home_keyword_list(rebuild: true)
    get_city_list(rebuild: true)
    get_sector_list(rebuild: true)
    get_organisation_list(rebuild: true)
    get_products_list(rebuild: true)
    get_state_list(rebuild: true)
    get_filter_sectors(rebuild: true)
    Rails.cache.delete('home/todays_tender')
    p "Rebuild Complete: #{Time.now}"
  end

  def self.get_active_categories_list(string)
    string.split("\n").sort.map(&:strip).reject(&:empty?).uniq.map { |item|
      search_string = item.gsub('-', ' ')
      # search_string if TendersController.search_tender(search_string, 0, 10 ** 10).limit(1).present?
      begin
        @pagy, @records = TendersController.elastic_pagy(search_string, 1)
        if @records.present?
          return search_string
        end
      rescue
        return nil
      end
    }.reject(&:nil?)
  end

  def self.cache_keyword_list(name, keywords, options = {})
    list = Rails.cache.fetch(name)
    if list.nil? || options[:rebuild]
      p "cache miss key:#{name}, rebuild: #{options[:rebuild]}"
      keywords = File.read("app/files/categories/#{keywords}") if options[:type] == 'file'
      active_keywords = get_active_categories_list(keywords)
      Rails.cache.write(name, active_keywords, expire_in: 48.hours)
      active_keywords
    else
      p "cache hit key:#{name}"
      list
    end
  end

  def self.home_keyword_list(options = {})
    cache_keyword_list('home/home_keyword_list', 'home_keyword_list.txt', type: 'file', rebuild: options[:rebuild])
  end

  def self.get_city_list(options = {})
    cache_keyword_list('home/get_city_list', 'city_list.txt', type: 'file', rebuild: options[:rebuild])
  end

  def self.get_sector_list(options = {})
    cache_keyword_list('home/get_sector_list', 'sector_list.txt', type: 'file', rebuild: options[:rebuild])
  end

  def self.get_organisation_list(options = {})
    cache_keyword_list(
      'home/get_organisation_list',
      'organisations_list.txt',
      type: 'file', rebuild: options[:rebuild]
    )
  end

  # console.log($$('#edit-s-prod-type option').map(e => e.textContent).join('\n'))
  # https://eprocure.gov.in/cppp/latestactivetendersnew/cpppdata
  #
  def self.get_products_list(options = {})
    cache_keyword_list(
      'home/get_products_list',
      'products_list.txt',
      type: 'file', rebuild: options[:rebuild]
    )
  end

  def self.get_state_list(options = {})
    cache_keyword_list('home/get_state_list', 'state_list.txt', type: 'file', rebuild: options[:rebuild])
  end

  def self.get_filter_sectors(options = {})
    cache_keyword_list('home/get_sectors', 'filter_sectors.txt', type: 'file', rebuild: options[:rebuild])
  end
end
