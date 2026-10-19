# /find-a-partner?tender=<slug_uuid>: a bidder who can't meet a tender's
# eligibility alone (JV or consortium partner) or needs a team where the
# work is (subcontractor) asks the team to find one. Saved as a Lead.
class PartnerRequestsController < ApplicationController
  include LeadRequests

  before_action :set_tender
  before_action :no_cache

  def new
    @lead = build_lead(kind: 'partner', tender: @tender)
  end

  def create
    return redirect_to(find_partner_path(tender: @tender&.slug_uuid, sent: 1)) if bot?

    @lead = build_lead(lead_params.merge(kind: 'partner', tender: @tender))
    return render(:new, status: :unprocessable_entity) unless save_lead(@lead)

    redirect_to find_partner_path(tender: @tender&.slug_uuid, sent: 1)
  end

  private

  def set_tender
    uuid = params[:tender].to_s
    @tender = Tender.find_by(slug_uuid: uuid) if uuid.present?
  end

  def lead_params
    params.require(:lead).permit(:partner_need, :details, :company, :annual_turnover, :location,
                                 :name, :email, :phone)
  end
end
