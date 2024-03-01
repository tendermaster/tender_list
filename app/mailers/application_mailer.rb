class ApplicationMailer < ActionMailer::Base
  # default from: "notify@sigmatenders.com"
  default from: email_address_with_name('no-reply@sigmatenders.com',
                                        'SigmaTenders'),
          reply_to: 'tendermasterinfo@gmail.com'
  layout "mailer"

  def welcome_email
    @user = params[:user]
    @url  = 'http://example.com/login'
    mail(to: @user.email, subject: 'Welcome to My Awesome Site')
  end
end
