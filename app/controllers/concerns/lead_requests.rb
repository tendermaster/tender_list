# Shared by the forms that create Leads (product quotes, partner requests,
# enquiries, the tender-alert sidebar and checklist downloads): signed-in
# users' details come from their account, signed-out visitors pass the
# captcha, and what looks like spam is kept with status spam for review
# instead of reaching the call list.
module LeadRequests
  extend ActiveSupport::Concern

  included do
    # remote_ip is the visitor's: Caddy passes on Cloudflare's CF-Connecting-IP,
    # trusted only from Cloudflare's addresses (caddy/conf/Caddyfile)
    rate_limit to: 5, within: 1.hour, only: :create, by: -> { request.remote_ip },
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

  def no_cache
    response.headers['Cache-Control'] = 'no-cache, no-store, private, max-age=0'
  end

  # Saves the lead. Returns true, :spam (kept with status spam, or dropped if
  # it isn't even valid; the visitor is thanked either way, so bots learn
  # nothing), or false with the errors on the lead.
  def save_lead(lead)
    if (reason = spam_reason(lead))
      # Kept for review even when it's junk that wouldn't pass validation
      # (bots fill a fake phone or email); spam stays off the call list.
      # Only what the database itself refuses (a missing email) is dropped.
      lead.assign_attributes(status: :spam, note: "Spam: #{reason}")
      kept = begin
        lead.save(validate: false)
      rescue ActiveRecord::NotNullViolation
        false
      end
      Rails.logger.info("Lead marked spam (#{reason}#{', not kept' unless kept}): #{lead.kind} #{lead.topic || lead.product_id}")
      return :spam
    end
    if current_user.nil? && !verify_captcha
      lead.errors.add(:base, "Please confirm you're not a robot and try again")
      return false
    end
    return false unless lead.save

    remember_on_account(lead)
    # A GA4 generate_lead event on the next page (layouts/_lead_event): only
    # for real leads, never spam
    flash[:lead_event] = lead.enquiry? ? lead.topic : lead.kind
    true
  end

  # Signed-in users are people; the rest go through SpamFilter
  def spam_reason(lead)
    return if current_user

    SpamFilter.reason(honeypot: params[:website], fill_ms: params[:fill_ms], email: lead.email,
                      texts: [lead.name, lead.email, lead.phone, lead.company, lead.details, lead.quantity,
                              lead.location, *lead.answers.except('Website').values])
  end

  # A signed-in user's account keeps the mobile and turnover they gave
  # with the request, if it had none
  def remember_on_account(lead)
    return if current_user.nil?

    current_user.phone = lead.phone if current_user.phone.blank? && Phonelib.parse(lead.phone).country == 'IN'
    current_user.annual_turnover = lead.annual_turnover if current_user.annual_turnover.blank?
    current_user.contact_consent_at ||= Time.current
    current_user.save if current_user.changed?
  end
end
