class FillSimilarTendersJob
  include Sidekiq::Job

  def perform(query, exclude_id)
    # to stop further same request until cache is filled
    Rails.cache.write("similar_tenders/#{query}", [], expire_in: 10.minutes)
    tenders = Tender.where([
                             "ts_rank(tender_text_vector, websearch_to_tsquery('english', ?)) > 0.6 and id != ?",
                             query,
                             exclude_id
                           ]).order(submission_close_date: :desc).limit(10)
    Rails.cache.write("similar_tenders/#{query}", tenders, expire_in: 4.days)
  end
end

# clear cache
# Rails.cache.delete_matched('similar_tenders/%')
