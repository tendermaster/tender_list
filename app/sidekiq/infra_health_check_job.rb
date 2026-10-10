class InfraHealthCheckJob
  include Sidekiq::Job

  # Read-only checks that report to Sentry when something drifts. Each threshold
  # maps to a problem that once went unnoticed for months.
  MAX_REDIS_MEMORY_RATIO = 0.80   # of maxmemory
  MAX_SESSIONS = 100_000          # crawlers once created ~10M sessions
  MAX_ES_DELETED_RATIO = 0.25     # ExpungeEsDeletesJob should keep this low
  SESSIONS_DB = 1
  EVICTED_KEYS_CACHE_KEY = 'infra_health:evicted_keys'

  def perform(*args)
    Telemetry::Tracer.in_span('cron.infra_health_check') do
      problems = check_redis + check_sidekiq + check_elasticsearch
      if problems.empty?
        Rails.logger.info('InfraHealthCheckJob: all checks passed')
      else
        message = "Infra health check: #{problems.join('; ')}"
        Rails.logger.warn(message)
        Sentry.capture_message(message, level: :warning)
      end
    end
  end

  private

  def check_redis
    info = Sidekiq.redis { |r| r.call('INFO') }
    stats = info.lines.each_with_object({}) do |line, h|
      key, value = line.strip.split(':', 2)
      h[key] = value if value
    end

    problems = []
    used = stats['used_memory'].to_i
    max = stats['maxmemory'].to_i
    if max.positive? && used > max * MAX_REDIS_MEMORY_RATIO
      problems << "Redis memory #{(used * 100.0 / max).round}% of maxmemory"
    end

    sessions = stats["db#{SESSIONS_DB}"].to_s[/keys=(\d+)/, 1].to_i
    problems << "#{sessions} sessions in Redis db#{SESSIONS_DB}" if sessions > MAX_SESSIONS

    evicted = stats['evicted_keys'].to_i
    previous = Rails.cache.read(EVICTED_KEYS_CACHE_KEY)
    Rails.cache.write(EVICTED_KEYS_CACHE_KEY, evicted, expires_in: 3.days)
    if previous && evicted > previous
      problems << "Redis evicted #{evicted - previous} keys since last check"
    end

    problems
  rescue StandardError => e
    ["Redis check failed: #{e.message}"]
  end

  def check_sidekiq
    problems = []
    dead = Sidekiq::DeadSet.new.size
    retries = Sidekiq::RetrySet.new.size
    problems << "#{dead} jobs in Sidekiq dead set" if dead.positive?
    problems << "#{retries} jobs waiting to retry" if retries.positive?
    problems
  rescue StandardError => e
    ["Sidekiq check failed: #{e.message}"]
  end

  def check_elasticsearch
    stats = ElasticClient.cat.indices(index: TenderSearch::ES_INDEX, h: 'health,docs.count,docs.deleted', format: 'json').first
    problems = []
    problems << "Elasticsearch #{TenderSearch::ES_INDEX} health #{stats['health']}" unless stats['health'] == 'green'

    live = stats['docs.count'].to_i
    deleted = stats['docs.deleted'].to_i
    ratio = deleted.to_f / [live + deleted, 1].max
    problems << "Elasticsearch #{(ratio * 100).round}% deleted docs" if ratio > MAX_ES_DELETED_RATIO
    problems
  rescue StandardError => e
    ["Elasticsearch check failed: #{e.message}"]
  end
end
