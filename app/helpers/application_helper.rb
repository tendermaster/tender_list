module ApplicationHelper
  include Pagy::Frontend

  def time_left(time)
    # time.is_a?(ActiveSupport::TimeWithZone) ? "#{distance_of_time_in_words(Date.today, time, true, highest_measure_only: true)} left" : '-'
    duration = ((time - Time.zone.now) / 1.day).floor
    duration if time.is_a?(ActiveSupport::TimeWithZone)
    # time.is_a?(ActiveSupport::TimeWithZone) and duration >= 0 ? "#{duration} days left" : "Expired #{duration*-1} days ago"
    #   result.submission_close_date.is_a?(ActiveSupport::TimeWithZone) ? "#{distance_of_time_in_words(Date.today,result.submission_close_date, true, highest_measure_only: true)} left" : '-'
  end

  def time_left_text(submission_close_date)
    if time_left(submission_close_date) >= 0
      "#{time_left(submission_close_date)} days left"
    else
      "Expired #{time_left(submission_close_date).abs} days ago"
    end
  end

  def currency_format(amt)
    amt_len = amt.to_s.length
    if amt_len < 6
      amt
    elsif amt_len in 6..7
      amt_rounded = (amt.to_f / 10**5).round(2)
      if amt_rounded.to_s.split('.')[-1] == '0'
        "#{amt_rounded.to_i} Lakh"
      else
        "#{amt_rounded} Lakh"
      end
    else
      amt_rounded = (amt.to_f / 10**7).round(2)
      if amt_rounded.to_s.split('.')[-1] == '0'
        "#{amt_rounded.to_i} Crore"
      else
        "#{amt_rounded} Crore"
      end
    end
  end

  def generate_faq(data)
    JSON.pretty_generate(
      '@context': 'https://schema.org',
      '@type': 'FAQPage',
      'mainEntity': data.each_with_index do |ques|
        {
          '@type': 'Question',
          'name': ques[:name],
          'acceptedAnswer': {
            '@type': 'Answer',
            'text': ques[:ans]
          }
        }
      end
    )
  end

  def is_tender_id?(string)
    if (string.length <= 40 && string.scan('/').length >= 3) ||
      (string.strip.scan(' ').empty? && string.scan('/').length >= 2 && string.length <= 30)
      true
    else
      false
    end
  end

  # TODO: enable get active list and cache

  def get_active_categories_list(string)
    string.split("\n").sort.map(&:strip).reject(&:empty?).map { |item|
      item if TendersController.search_tender(item, 0, 10**10).limit(1).present?
    }.reject(&:nil?)
  end

  def gem_keyword_list
    ''
  end

  def cache_keyword_list(name, keywords, options = {})
    list = Rails.cache.fetch(name)
    if list.nil?
      keywords = File.read("app/files/categories/#{keywords}") if options[:type] == 'file'
      active_keywords = get_active_categories_list(keywords)
      Rails.cache.write(name, active_keywords, expire_in: 4.hours)
      p "cache miss key:#{name}"
      active_keywords
    else
      p "cache hit key:#{name}"
      list
    end
  end

  def home_keyword_list
    cache_keyword_list('home/home_keyword_list', 'home_keyword_list.txt', type: 'file')
  end

  def get_city_list
    cache_keyword_list('home/get_city_list', 'city_list.txt', type: 'file')
  end

  def get_sector_list
    cache_keyword_list('home/get_sector_list', 'sector_list.txt', type: 'file')
  end

  def get_organisation_list
    cache_keyword_list(
      'home/get_organisation_list',
      'organisations_list.txt',
      type: 'file'
    )
  end

  # console.log($$('#edit-s-prod-type option').map(e => e.textContent).join('\n'))
  # https://eprocure.gov.in/cppp/latestactivetendersnew/cpppdata
  #
  def get_products_list
    cache_keyword_list(
      'home/get_products_list',
      'products_list.txt',
      type: 'file'
    )
  end

  def get_state_list
    cache_keyword_list('home/get_state_list', 'state_list.txt', type: 'file')
  end

  def get_filter_sectors
    cache_keyword_list('home/get_sectors', "filter_sectors.txt", type: 'file')
  end

end
