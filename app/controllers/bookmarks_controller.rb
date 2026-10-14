# A user's saved tenders: the list at /dashboard/bookmarks, and the Save
# buttons on tender cards and pages (bookmark_controller.js), which add and
# remove one with JSON requests.
class BookmarksController < ApplicationController
  before_action :authenticate_user!
  before_action :no_store

  def index
    bookmarks = current_user.bookmarks.includes(:tender).order(created_at: :desc).to_a.select(&:tender)
    now = Time.current
    open, closed = bookmarks.partition { |b| b.tender.submission_close_date.nil? || b.tender.submission_close_date > now }
    # Open: the soonest closing first. Closed: the latest closed first.
    @open = open.sort_by { |b| b.tender.submission_close_date || 100.years.from_now }
    @closed = closed.sort_by { |b| b.tender.submission_close_date }.reverse
  end

  def create
    tender = Tender.find_by(slug_uuid: params[:slug_uuid])
    return head :not_found unless tender

    current_user.bookmarks.find_or_create_by!(tender:)
    render json: { bookmarked: true }
  rescue ActiveRecord::RecordNotUnique
    render json: { bookmarked: true } # saved by a simultaneous click
  end

  def destroy
    tender = Tender.find_by(slug_uuid: params[:slug_uuid])
    current_user.bookmarks.where(tender:).delete_all if tender
    respond_to do |format|
      format.json { render json: { bookmarked: false } }
      format.html { redirect_to bookmarks_path, notice: 'Removed from saved tenders' }
    end
  end

  private

  def no_store
    response.headers['Cache-Control'] = 'no-cache, no-store, private, max-age=0'
  end
end
