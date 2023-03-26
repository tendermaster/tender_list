class ApplicationController < ActionController::Base
  include Pagy::Backend
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from Pagy::OverflowError, with: :record_not_found

  def after_sign_in_path_for(users)
    queries_path
  end

  def time_left(time)
    time.is_a?(ActiveSupport::TimeWithZone) ? "#{distance_of_time_in_words(Date.today, time, true, highest_measure_only: true)} left" : '-'
    #   result.submission_close_date.is_a?(ActiveSupport::TimeWithZone) ? "#{distance_of_time_in_words(Date.today,result.submission_close_date, true, highest_measure_only: true)} left" : '-'
  end
  helper_method :time_left

  # TODO: cache value
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
    Puducherry".split("\n").sort.map {|state| state.strip}
  end
  helper_method :get_states

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
    PSU".split("\n").sort.map {|sector| sector.strip}
  end
  helper_method :get_sectors

  private
  def record_not_found
    render 'home/page_404', status: 404
  end

end
