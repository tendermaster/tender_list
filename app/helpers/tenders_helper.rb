module TendersHelper
  include Pagy::Frontend

  def tender_bookmarked?(user_id, tender_id)
    marked = Bookmark.find_by({ user_id: user_id, tender_id: tender_id })
    if marked.present?
      true
    else
      false
    end
  end

end
