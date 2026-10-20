# The home page's industry checklist download (tenders/shared/_cheklist_download):
# saved as a checklist_download enquiry Lead, then the files are emailed, or
# shown on the page while mail is off. The home page is CDN-cached without a
# session, so the form has no CSRF token and is guarded by the captcha and
# SpamFilter instead.
class ChecklistDownloadsController < ApplicationController
  include LeadRequests

  skip_forgery_protection only: :create

  def create
    report = helpers.checklist_options('get_code', params[:report_type].to_s)
    return reply('Please choose your industry') unless report

    @lead = build_lead(kind: 'enquiry', topic: 'checklist_download', name: params[:full_name], email: params[:email],
                       phone: params[:phone], answers: { 'Checklist' => report[:label] })
    result = save_lead(@lead)
    return reply("Please check the form: #{@lead.errors.full_messages.to_sentence}") unless result
    # Spam is shown the usual message, without the files
    return reply('Please check your email (including the spam folder) to download your files') if result == :spam

    if ActionMailer::Base.perform_deliveries
      CheckListDownloaderMailer.send_check_list(@lead.email, report).deliver_later
      reply('Please check your email (including the spam folder) to download your files')
    else
      # Mail is off (MAIL_ENABLED): show the links instead of emailing them
      @report_data = report
      reply("Your #{report[:label]} files are ready")
    end
  end

  private

  def reply(message)
    @full_message = message
    render 'tenders/get_relevant_tenders_success'
  end
end
