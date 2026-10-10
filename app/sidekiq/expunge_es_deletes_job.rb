class ExpungeEsDeletesJob
  include Sidekiq::Job

  # Logstash re-syncs updated tenders, leaving the old copies as deleted docs
  # (2.1M / 38% had piled up), which bloats the index and slows every search.
  MIN_DELETED_RATIO = 0.10

  def perform(*args)
    Telemetry::Tracer.in_span('cron.expunge_es_deletes') do
      stats = ElasticClient.cat.indices(index: TenderSearch::ES_INDEX, h: 'docs.count,docs.deleted', format: 'json').first
      live = stats['docs.count'].to_i
      deleted = stats['docs.deleted'].to_i
      ratio = deleted.to_f / [live + deleted, 1].max

      if ratio < MIN_DELETED_RATIO
        Rails.logger.info("ExpungeEsDeletesJob: #{(ratio * 100).round(1)}% deleted, skipping")
        return
      end

      # Runs as a background task in Elasticsearch; don't hold the job open for it.
      task = ElasticClient.indices.forcemerge(index: TenderSearch::ES_INDEX, only_expunge_deletes: true,
                                              wait_for_completion: false)
      Rails.logger.info("ExpungeEsDeletesJob: #{deleted} deleted docs (#{(ratio * 100).round(1)}%), started #{task['task']}")
    end
  end
end
