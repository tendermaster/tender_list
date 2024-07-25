class CheckListDownloaderMailer < ApplicationMailer
  default from: email_address_with_name('no-reply@sigmatenders.com',
                                        'SigmaTenders'),
          reply_to: 'tendermasterinfo@gmail.com'
  layout "mailer"

  def send_check_list(email, report_data)
    @report_data = report_data

    mail(to: email, subject: "SigmaTenders [#{@report_data[:label]}] Dockets")
  end

end
