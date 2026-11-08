# /enquiry/<topic>: the forms in config/enquiry_topics.yml, which replaced
# the Google Forms (services, supplier registration, callback, RFQ, ...).
# Saved as Leads of kind enquiry, with the answers keyed by question.
# ?tender=<slug_uuid> links the lead to the tender it came from (the bid
# help button on tender pages).
class EnquiriesController < ApplicationController
  include LeadRequests

  before_action :set_topic
  before_action :set_tender
  before_action :no_cache

  def show
    @lead = build_lead(kind: 'enquiry', topic: @topic.key, tender: @tender)
  end

  def create
    attrs = params.require(:lead).permit(:name, :email, :phone, :company, :designation, :website,
                                         answers: @topic.permitted_answers)
    @lead = build_lead(attrs.slice(:name, :email, :phone, :company)
                            .merge(kind: 'enquiry', topic: @topic.key, tender: @tender, answers: @topic.answers_from(attrs)))
    return render(:show, status: :unprocessable_entity) unless save_lead(@lead)

    redirect_to enquiry_path(@topic.key, tender: @tender&.slug_uuid, sent: 1)
  end

  private

  def set_topic
    @topic = EnquiryTopic.find(params[:topic])
    record_not_found unless @topic&.form?
  end
end
