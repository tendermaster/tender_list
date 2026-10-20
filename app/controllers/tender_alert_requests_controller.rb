# The "Get customized tender recommendations" form in the tender and search
# sidebars (tenders/_get_relevant_tenders_form): saved as a tender_alerts
# enquiry Lead. Those pages are CDN-cached without a session, so the form has
# no CSRF token and is guarded by the captcha and SpamFilter instead.
class TenderAlertRequestsController < ApplicationController
  include LeadRequests

  skip_forgery_protection only: :create

  def create
    topic = EnquiryTopic.find('tender_alerts')
    answers = topic.answers_from(ActiveSupport::HashWithIndifferentAccess.new(answers: { keywords: params[:sectors] }))
    @lead = build_lead(kind: 'enquiry', topic: topic.key, name: params[:name], email: params[:email],
                       phone: params[:mobile], answers:)
    @full_message = if save_lead(@lead)
                      'Thank you. We will send you tenders that match your business.'
                    else
                      "Please check the form: #{@lead.errors.full_messages.to_sentence}"
                    end
    render 'tenders/get_relevant_tenders_success'
  end
end
