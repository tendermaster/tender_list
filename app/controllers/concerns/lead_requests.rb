# Shared by the forms that create Leads (product quotes, partner requests):
# signed-in users' details come from their account, signed-out visitors
# pass the captcha, and bots that fill the hidden "website" field are dropped.
module LeadRequests
  extend ActiveSupport::Concern

  included do
    # Behind Cloudflare, remote_ip is Cloudflare's
    rate_limit to: 5, within: 1.hour, only: :create, by: -> { request.headers['CF-Connecting-IP'] || request.remote_ip },
               with: -> { render plain: 'Too many requests. Please try again in an hour.', status: :too_many_requests }
  end

  private

  def build_lead(attrs = {})
    lead = Lead.new(attrs)
    return lead if current_user.nil?

    lead.user = current_user
    lead.name = current_user.name if lead.name.blank?
    lead.name = current_user.email.split('@').first if lead.name.blank?
    lead.email = current_user.email
    lead.phone = current_user.phone if current_user.phone.present?
    lead.annual_turnover ||= current_user.annual_turnover
    lead
  end

  def bot? = params[:website].present?

  # Saves the lead, unless the captcha fails for a signed-out visitor
  def save_lead(lead)
    if current_user.nil? && !verify_captcha
      lead.errors.add(:base, "Please confirm you're not a robot and try again")
      return false
    end
    return false unless lead.save

    remember_on_account(lead)
    true
  end

  # A signed-in user's account keeps the mobile and turnover they gave
  # with the request, if it had none
  def remember_on_account(lead)
    return if current_user.nil?

    current_user.phone = lead.phone if current_user.phone.blank?
    current_user.annual_turnover = lead.annual_turnover if current_user.annual_turnover.blank?
    current_user.contact_consent_at ||= Time.current
    current_user.save if current_user.changed?
  end
end
