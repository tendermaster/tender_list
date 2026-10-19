# Product buying guides (/products/cctv-cameras) with a "Get quote" form.
# Pages are cached at the CDN for signed-out visitors, so they have no
# session or CSRF token; the form is guarded by the captcha instead, like the
# other anonymous lead forms.
class ProductsController < ApplicationController
  include LeadRequests

  skip_forgery_protection only: :create
  before_action :set_product, only: %i[show create]

  def index
    set_public_cache(cdn_ttl: 12.hours)
    @products = Product.published.ordered.group_by(&:category)
  end

  def show
    set_public_cache(cdn_ttl: 12.hours)
    @lead = build_lead(product: @product)
  end

  def create
    return redirect_to(product_path(@product, quoted: 1)) if bot?

    @lead = build_lead(lead_params.merge(product: @product, kind: 'quote'))
    return render(:show, status: :unprocessable_entity) unless save_lead(@lead)

    redirect_to product_path(@product, quoted: 1)
  end

  private

  def set_product
    @product = Product.published.find_by(slug: params[:slug])
    record_not_found unless @product
  end

  def lead_params
    params.require(:lead).permit(:name, :email, :phone, :quantity, :location, :needed_by, :details)
  end
end
