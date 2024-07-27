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
    JSON.pretty_generate({
                           '@context': 'https://schema.org',
                           '@type': 'FAQPage',
                           'mainEntity': data.map do |ques|
                             {
                               '@type': 'Question',
                               'name': ques[:name],
                               'acceptedAnswer': {
                                 '@type': 'Answer',
                                 'text': ques[:ans]
                               }
                             }
                           end
                         })
  end

  def is_tender_id?(string)
    if (string.length <= 40 && string.scan('/').length >= 3) ||
      (string.strip.scan(' ').empty? && string.scan('/').length >= 2 && string.length <= 30)
      true
    else
      false
    end
  end

  def checklist_options(opts, code = nil)
    data = [
      {
        label: 'Constructions and Infrastructure Tenders',
        files: [
          { name: 'Guide to Applying for Construction & Infrastructure Tenders', link: 'https://drive.google.com/open?id=1MMtfKgULTG2oWDQZ28YITG5yrQSHNObQ&usp=drive_copy' },
          { name: 'Tentative checklist for Construction and Infrastructure Tenders', link: 'https://drive.google.com/open?id=1O6M59GCxKgDpaURBnXi86josArhkrKVc&usp=drive_copy' },
        ],
        code: 'construction'
      },
      {
        label: 'Man Power Tenders',
        files: [
          { name: 'Guide to Applying for Manpower Supply Tenders', link: 'https://drive.google.com/open?id=1_Ev3tyUU8CNXpvY4j2RWWC4i_z7qlTpP&usp=drive_copy' },
          { name: 'Tentative checklist for Manpower Supply Tenders', link: 'https://drive.google.com/open?id=19g01AxKiVvcrhK7CUElBpMtGY7UVlhAe&usp=drive_copy' },
        ],
        code: 'manpower'
      },
      {
        label: 'Website & Software Development Tenders',
        files: [
          { name: 'Guide to Applying for Website development and software devlopment', link: 'https://drive.google.com/open?id=1oXHqI0amSti3FR-3kfqKyLiSYB7Bbo5B&usp=drive_copy' },
          { name: 'Tentative checklist of information and documents commonly required for website and software development tenders', link: 'https://drive.google.com/open?id=1csrEBTb2CYVlHgLbthQfJkDO9gKBB8CW&usp=drive_copy' },
        ],
        code: 'website'
      },
      {
        label: 'Skill Development & Training Tenders',
        files: [
          { name: 'Guide to Applying for Skill Development', link: 'https://drive.google.com/open?id=1qnYmE-JnBVsBLOPrNMHBkpQ8ivu1cjnK&usp=drive_copy' },
          { name: 'Tentative checklist for applying for Skill Development and Training Tenders', link: 'https://drive.google.com/open?id=1mbzvwv58toh_PtLTf-cNRQn6xQblG44X&usp=drive_copy' },
        ],
        code: 'skill'
      },
      {
        label: 'NGO Service tenders',
        files: [
          { name: 'Guide to Applying for NGO Service Tenders', link: 'https://drive.google.com/open?id=1oKz5LCkOKV6XN6k_amXWPbNJ_iNoLK2x&usp=drive_copy' },
          { name: 'Tentative checklist for NGO Service Tenders', link: 'https://drive.google.com/open?id=1ws2rZJO0IC3i8usHTZ-5DuxMBIgBrd1f&usp=drive_copy' },
        ],
        code: 'ngo'
      },
      {
        label: 'Legal Services',
        files: [
          { name: 'Guide to Applying for Legal Services Tenders', link: 'https://drive.google.com/open?id=1Q-AxZhSG-VuyG_LEfdEgGkCxUiHgJcz_&usp=drive_copy' },
          { name: 'Tentative checklist for Legal Services Tenders', link: 'https://drive.google.com/open?id=19Q3t7hmTnTWMJX-O3UQ3KmTA5y9iKH-j&usp=drive_copy' },
        ],
        code: 'legal'
      },
      {
        label: 'Manufacturing and Production',
        files: [
          { name: 'Guide to Applying for Manufacturing and production tenders', link: 'https://drive.google.com/open?id=1NP5OrKH1du8u5vcKZoEtIiQxRB68KPjp&usp=drive_copy' },
          { name: 'Tentative checklist for Manufacturing and Production', link: 'https://drive.google.com/open?id=1dHx_rUnKmq8xEgLOdIVJK6zyhoXlnE6n&usp=drive_copy' },
        ],
        code: 'manufacture'
      },
      {
        label: 'Electrical Supply',
        files: [
          { name: 'Guide to Applying for Electrical Supply Tenders', link: 'https://drive.google.com/open?id=1uy7Gt1yGEAlvc_qDMStaGwYpTLTROT-N&usp=drive_copy' },
          { name: 'Tentative checklist for Electrical Supply Tenders', link: 'https://drive.google.com/open?id=1VtF3smi1_MtPXXS2StVhCK7FfWPYtKPA&usp=drive_copy' },
        ],
        code: 'electrical'
      },
      {
        label: 'Garden Maintenance & Horticulture Tenders',
        files: [
          { name: 'Checklist for Garden Maintenance', link: 'https://drive.google.com/open?id=13kVTp7RX-u3gKu-G3fisOom3jsX953Ib&usp=drive_copy' },
          { name: 'Guide to Applying for Garden Maintenance and horticulture Tenders', link: 'https://drive.google.com/open?id=1fXw9BUGLrRV0GUVpkpme9VLggKv7vhLe&usp=drive_copy' },
        ],
        code: 'garden-maintenance'
      },
      {
        label: 'Vehicle Hire, Logistics, & Transportation Tenders',
        files: [
          { name: 'Guide to Applying for Vehicle Hire', link: 'https://drive.google.com/open?id=1kKsLdZwcUduAS5oLxwbTaf6mElNQdNbY&usp=drive_copy' },
          { name: 'Tentative checklist for Vehicle Hire', link: 'https://drive.google.com/open?id=1P8AubiIkY8c6EMDAaAlSaR6tCvUNOQmT&usp=drive_copy' },
        ],
        code: 'vehicle-hire'
      },
      {
        label: 'Catering Services Tenders',
        files: [
          { name: 'Checklist for Catering Services Tenders', link: 'https://drive.google.com/open?id=1rL7sVxZqMqu0mkbOMzvQC00u-fx2OS9l&usp=drive_copy' },
          { name: 'Guide to Applying for Catering Services Tenders', link: 'https://drive.google.com/open?id=1Y6umU7C_TUZGptmGBDz5_8bekXcGGvuc&usp=drive_copy' },
        ],
        code: 'catering'
      },
      {
        label: 'Audit Firms',
        files: [
          { name: 'Guide to Applying for Audit Firm Tenders', link: 'https://drive.google.com/open?id=1ctHnyxN1Q3I30lDwHNcHSMpv3zBFemW6&usp=drive_copy' },
          { name: 'Tentative checklist for Audit Firm Tenders', link: 'https://drive.google.com/open?id=1E3C6nh4wvHVkm-V8xCzcSXaQjI_YBGlH&usp=drive_copy' },
        ],
        code: 'audit'
      },

      # {
      #   label: 'Legal Services',
      #   files: [
      #     { name: 'checklist', link: 'https://drive.google.com/open?id=1Q-AxZhSG-VuyG_LEfdEgGkCxUiHgJcz_&usp=drive_copy' },
      #     { name: 'checklist', link: 'https://drive.google.com/open?id=1Q-AxZhSG-VuyG_LEfdEgGkCxUiHgJcz_&usp=drive_copy' },
      #   ],
      #   code: 'legal'
      # }
    ]
    case opts
    when 'form'
      # form_option = {}
      form_option = []
      data.each do |d|
        # form_option[d[:label]] =
          # [["Guide to Applying for #{d[:label]} Tenders", d[:code]], ["Checklist for #{d[:label]} Tenders", d[:code]]]
        form_option.append([d[:label], d[:code]])
      end
      form_option
    when 'get_code'
      data.select { |d| d[:code] == code }.first
    end
  end

  def current_time
    TZInfo::Timezone.get('Asia/Kolkata').now.strftime('%d-%b-%Y %I:%M %p')
  end

  # class CheckListOptions
  #   def initialize
  #     @data = [{
  #                label: "Legal Services",
  #                files: [
  #                  { name: 'checklist', link: "https://drive.google.com/open?id=1Q-AxZhSG-VuyG_LEfdEgGkCxUiHgJcz_&usp=drive_copy" },
  #                  { name: 'checklist', link: "https://drive.google.com/open?id=1Q-AxZhSG-VuyG_LEfdEgGkCxUiHgJcz_&usp=drive_copy" },
  #                ],
  #                code: 'legal'
  #              }]
  #     @data_hash = {}
  #     @data.each do |d|
  #       @data_hash[d[:code]] = d
  #     end
  #   end
  #
  #   def self.get_code(code)
  #     # data.select { |d| d[:code] == code }.first
  #     @data_hash[code]
  #   end
  #
  #   def self.get_form
  #     form_option = {}
  #     data.each do |d|
  #       form_option[d[:label]] =
  #         [["Guide to Applying for #{d[:label]} Tenders", d[:code]], ["Checklist for #{d[:label]} Tenders", d[:code]]]
  #     end
  #     form_option
  #   end
  #
  # end

end
