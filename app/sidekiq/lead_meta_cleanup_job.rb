class LeadMetaCleanupJob
  include Sidekiq::Job

  # Spam leads keep their IP, headers and page (request_meta) for 90 days, long
  # enough to spot patterns; real leads keep theirs with the lead
  KEEP_SPAM_META = 90.days

  def perform
    Lead.spam.where(created_at: ...KEEP_SPAM_META.ago).where.not(request_meta: {}).update_all(request_meta: {})
  end
end
