# /enquiry/<topic>: the forms in config/enquiry_topics.yml, which replaced
# the Google Forms (services, supplier registration, callback, RFQ, ...).
# Saved as Leads of kind enquiry, with the answers keyed by question.
class EnquiriesController < ApplicationController
  include LeadRequests

  before_action :set_topic
  before_action :no_cache

  def show
    @lead = build_lead(kind: 'enquiry', topic: @topic.key)
  end

  def create
    attrs = params.require(:lead).permit(:name, :email, :phone, :company, :designation, :website,
                                         answers: @topic.permitted_answers)
    @lead = build_lead(attrs.slice(:name, :email, :phone, :company)
                            .merge(kind: 'enquiry', topic: @topic.key, answers: @topic.answers_from(attrs)))
    return render(:show, status: :unprocessable_entity) unless save_lead(@lead)

    redirect_to enquiry_path(@topic.key, sent: 1)
  end

  private

  def set_topic
    @topic = EnquiryTopic.find(params[:topic])
    record_not_found unless @topic&.form?
  end
end
