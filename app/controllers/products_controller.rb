# Product buying guides (/products/cctv-cameras) with a "Get quote" form.
# Pages are cached at the CDN for signed-out visitors, so they have no
# session or CSRF token; the form is guarded by the captcha instead, like the
# other anonymous lead forms. Signed-in users quote with their own email and
# onboarding mobile.
class ProductsController < ApplicationController
  skip_forgery_protection only: :quote
  before_action :set_product, only: %i[show quote]
  # Behind Cloudflare, remote_ip is Cloudflare's
  rate_limit to: 5, within: 1.hour, only: :quote, by: -> { request.headers['CF-Connecting-IP'] || request.remote_ip },
             with: -> { render plain: 'Too many quote requests. Please try again in an hour.', status: :too_many_requests }

  def index
    set_public_cache(cdn_ttl: 12.hours)
    @products = Product.published.ordered.group_by(&:category)
  end

  def show
    set_public_cache(cdn_ttl: 12.hours)
    @lead = new_lead
  end

  def quote
    # Bots fill in every field, including this hidden one
    return redirect_to(product_path(@product, quoted: 1)) if params[:website].present?

    @lead = new_lead(lead_params)
    if current_user.nil? && !verify_captcha
      @lead.errors.add(:base, "Please confirm you're not a robot and try again")
      return render(:show, status: :unprocessable_entity)
    end
    return render(:show, status: :unprocessable_entity) unless @lead.save

    remember_phone(@lead)
    redirect_to product_path(@product, quoted: 1)
  end

  private

  def set_product
    @product = Product.published.find_by(slug: params[:slug])
    record_not_found unless @product
  end

  # Signed-in users' name, email and (if they have one) mobile come from
  # their account
  def new_lead(attrs = {})
    lead = @product.leads.build(attrs)
    return lead if current_user.nil?

    lead.user = current_user
    lead.name = current_user.name if lead.name.blank?
    lead.email = current_user.email
    lead.phone = current_user.phone if current_user.phone.present?
    lead
  end

  # A signed-in user without a mobile gave one with their request: keep it,
  # so the "Finish setup" bar stops asking
  def remember_phone(lead)
    return if current_user.nil? || current_user.phone.present?

    current_user.update(phone: lead.phone, contact_consent_at: current_user.contact_consent_at || Time.current)
  end

  def lead_params
    params.require(:lead).permit(:name, :email, :phone, :quantity, :location, :needed_by, :details)
  end
end
