module Madmin
  class LeadsController < Madmin::ResourceController
    private

    # Spam is kept for review (LeadRequests#save_lead) but only listed under
    # the Spam tab, not mixed into All, Enquiry and the rest
    def scoped_resources
      valid_scope.to_s == 'spam' ? super : super.where.not(status: :spam)
    end
  end
end
