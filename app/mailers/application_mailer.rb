class ApplicationMailer < ActionMailer::Base
  default from: "notify@sigmatenders.com"
  layout "mailer"

  def welcome_email
    @user = params[:user]
    @url  = 'http://example.com/login'
    mail(to: @user.email, subject: 'Welcome to My Awesome Site')
  end

  def send_tender_updates
    email = params[:email]
    @tender_count = params[:tender_count]
    @query_id = params[:query_id]
    @query_name = params[:query_name]
    # @tenders = params[:tenders]
    mail(to: email, subject: "You have #{@tender_count} new tenders on [#{@query_name}]: SigmaTenders")
  end
end

# ApplicationMailer.with(email: 'a@a.a', tenders: [{title: 't', description: 'd'}]).send_tender_updates.deliver_later!


