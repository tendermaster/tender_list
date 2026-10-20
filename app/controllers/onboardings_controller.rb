# /welcome: a new user's mobile number and what they bid on, so the team can
# call them with matching tenders. New users land here after their first
# sign-in; the "Finish setup" bar brings back anyone without a number.
class OnboardingsController < ApplicationController
  before_action :authenticate_user!
  before_action :no_cache
  helper_method :return_to

  KEYWORD_SUGGESTIONS = ['Civil works', 'Road construction', 'Electrical works', 'Solar', 'CCTV', 'Medical equipment',
                         'Housekeeping', 'Security services', 'Furniture', 'IT hardware', 'Printing', 'Vehicle hiring'].freeze

  def show
    @query = current_user.query.order(:id).first
    @form = form_values(@query)
  end

  def update
    @form = form_values(nil).merge(onboarding_params.to_h.symbolize_keys)
    keywords = split_list(@form[:keywords])
    states = Array(@form[:states]).compact_blank & Query::STATES
    @errors = []
    @errors << 'Add at least one product or type of work you bid on' if keywords.empty?
    @errors << 'Please agree that we may call you' unless @form[:consent] == '1'

    current_user.assign_attributes(phone: @form[:phone], business_type: @form[:business_type].presence,
                                   annual_turnover: @form[:annual_turnover].presence,
                                   tender_values: Array(@form[:tender_values]) & User::TENDER_VALUE_BANDS,
                                   msme: @form[:msme] == '1', startup_india: @form[:startup_india] == '1')
    @errors << 'Enter a valid Indian mobile number' if current_user.phone.blank? || !current_user.valid?
    return render(:show, status: :unprocessable_entity) if @errors.any?

    query = save_interests(keywords, states)
    current_user.update!(contact_consent_at: current_user.contact_consent_at || Time.current,
                         onboarded_at: current_user.onboarded_at || Time.current)
    # Back to the page they signed up from (a tender), else their matches
    redirect_to return_to || query_result_path(query_id: query.id, onboarded: 1)
  end

  private

  # Where they were headed when they signed up: only paths on this site
  def return_to
    path = params[:return_to].to_s
    path if path.start_with?('/') && !path.start_with?('//')
  end

  # Updates their first saved search rather than adding one each time
  def save_interests(keywords, states)
    query = current_user.query.order(:id).first || current_user.query.build(name: 'My tenders')
    query.update!(include_keyword: keywords.join(', '), state_name: states.join(', '))
    query
  end

  def form_values(query)
    { keywords: query&.include_keyword.to_s, states: split_list(query&.state_name), phone: current_user.phone.to_s,
      business_type: current_user.business_type.to_s, annual_turnover: current_user.annual_turnover.to_s,
      tender_values: current_user.tender_values,
      msme: current_user.msme ? '1' : '0', startup_india: current_user.startup_india ? '1' : '0', consent: '1' }
  end

  def split_list(text) = text.to_s.split(',').map(&:squish).compact_blank.uniq

  def onboarding_params
    params.require(:onboarding).permit(:keywords, :phone, :business_type, :annual_turnover, :msme, :startup_india,
                                       :consent, states: [], tender_values: [])
  end

  def no_cache
    response.headers['Cache-Control'] = 'no-cache, no-store, private, max-age=0'
  end
end
