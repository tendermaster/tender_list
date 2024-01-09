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
end
