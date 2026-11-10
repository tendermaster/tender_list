# The "Get customized tender recommendations" form in the tender and search
# sidebars (tenders/_get_relevant_tenders_form): saved as a tender_alerts
# enquiry Lead. Those pages are CDN-cached without a session, so the form has
# no CSRF token and is guarded by the captcha and SpamFilter instead.
# On a tender page the form sends ?tender=<slug_uuid>, saved on the lead.
class TenderAlertRequestsController < ApplicationController
  include LeadRequests

  skip_forgery_protection only: :create
  before_action :set_tender

  def create
    topic = EnquiryTopic.find('tender_alerts')
    answers = topic.answers_from(ActiveSupport::HashWithIndifferentAccess.new(answers: { keywords: params[:sectors],
                                                                                       bid_help: params[:bid_help] }))
    @lead = build_lead(kind: 'enquiry', topic: topic.key, name: params[:name], email: params[:email],
                       phone: params[:mobile], answers:, tender: @tender)
    result = save_lead(@lead)
    if result == true
      track('tender_alert_requested', from_tender: @tender.present?, wants_bid_help: params[:bid_help] == 'Yes, help me bid',
                                      tender_open: (@tender.submission_close_date&.future? if @tender))
    end
    @full_message = if result
                      'Thank you. We will send you matching tenders on WhatsApp and call you.'
                    else
                      "Please check the form: #{@lead.errors.full_messages.to_sentence}"
                    end
    render 'tenders/get_relevant_tenders_success'
  end
end
