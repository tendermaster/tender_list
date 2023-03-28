module ApplicationHelper
  include Pagy::Frontend

  def time_left(time)
    time.is_a?(ActiveSupport::TimeWithZone) ? "#{distance_of_time_in_words(Date.today, time, true, highest_measure_only: true)} left" : '-'
    #   result.submission_close_date.is_a?(ActiveSupport::TimeWithZone) ? "#{distance_of_time_in_words(Date.today,result.submission_close_date, true, highest_measure_only: true)} left" : '-'
  end

  def currency_format(amt)
    amt_len = amt.to_s.length
    if amt_len < 6
      amt
    elsif amt_len in 6..7
      amt_rounded = (amt.to_f / 10 ** 5).round(2)
      if amt_rounded.to_s.split('.')[-1] == '0'
        "#{amt_rounded.to_i} Lakh"
      else
        "#{amt_rounded} Lakh"
      end
    else
      amt_rounded = (amt.to_f / 10 ** 7).round(2)
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
        p ques
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

  # TODO: cache value, memoize
  def get_states
    "Andhra Pradesh
    Arunachal Pradesh
    Assam
    Bihar
    Chhattisgarh
    Goa
    Gujarat
    Haryana
    Himachal Pradesh
    Jharkhand
    Karnataka
    Kerala
    Madhya Pradesh
    Maharashtra
    Manipur
    Meghalaya
    Mizoram
    Nagaland
    Odisha
    Punjab
    Rajasthan
    Sikkim
    Tamil Nadu
    Telangana
    Tripura
    Uttar Pradesh
    Uttarakhand
    West Bengal
    Andaman and Nicobar Islands
    Chandigarh
    Dadra and Nagar Haveli and Daman and Diu
    Delhi
    Jammu and Kashmir
    Ladakh
    Lakshadweep
    Puducherry".split("\n").sort.map { |state| state.strip }
  end

  def get_sectors
    "Central Government
    Defence
    Co-operatives
    Corporations
    Railway
    School & Colleges
    Associations
    Joint sector Semi-Government
    Universities
    Research Institute
    State Government
    Private sector
    Trust
    Bank
    PSU".split("\n").sort.map { |sector| sector.strip }
  end

end
