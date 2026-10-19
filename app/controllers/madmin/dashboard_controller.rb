module Madmin
  class DashboardController < Madmin::ApplicationController
    def show
      @users_total = User.count
      @users_week = User.where(created_at: 7.days.ago..).count
      @users_google = User.where.not(google_uid: nil).count
      @recent_users = User.order(created_at: :desc).limit(10)

      # Onboarding (/welcome) collects these for the team to call
      @to_call = User.where(call_status: nil, created_at: 30.days.ago..).order(created_at: :desc).limit(30).to_a
      @to_call_interests = Query.where(user_id: @to_call.map(&:id)).order(:id).group_by(&:user_id)

      # Product quotes and partner requests that nobody has called yet
      @leads = Lead.pending.includes(:product, :tender).order(created_at: :desc).limit(30).to_a

      @active_subscriptions = Subscription.where('end_date > now()').order(end_date: :asc).to_a
      # Subscription has no user association
      @subscribers = User.where(id: @active_subscriptions.map(&:user_id)).index_by(&:id)
      @revenue_30_days = Subscription.where(created_at: 30.days.ago..).sum(:price)

      @recent_queries = Query.includes(:user).order(created_at: :desc).limit(10)

      # The tenders table is ~20 GB: these use indexes, but a cold cache can
      # take seconds, so they're cached briefly
      @tenders = Rails.cache.fetch('madmin/dashboard/tenders', expires_in: 10.minutes) { tender_stats }
    end

    private

    def tender_stats
      by_source = Tender.where(updated_at_auto: 7.days.ago..)
                        .group(:tender_source)
                        .pluck(:tender_source,
                               Arel.sql("count(*) filter (where updated_at_auto > now() - interval '1 day')"),
                               Arel.sql('count(*)'),
                               Arel.sql('max(updated_at_auto)'))
      {
        # Planner estimate: an exact count reads the whole table
        total: Tender.connection.select_value("select reltuples::bigint from pg_class where relname = 'tenders'").to_i,
        open: Tender.where('submission_close_date > now()').count,
        sources: by_source.map { |source, day, week, last| { source:, day:, week:, last: } }
                          .sort_by { |s| -s[:week] },
        at: Time.current
      }
    end
  end
end
