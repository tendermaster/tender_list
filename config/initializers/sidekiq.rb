# frozen_string_literal: true

redis_host = ENV['REDIS_HOST']
redis_password = ENV['REDIS_PASSWORD']

redis_port = 6379
redis_db = 0

redis_url = if redis_password.present?
              "redis://:#{redis_password}@#{redis_host}:#{redis_port}"
            else
              "redis://#{redis_host}:#{redis_port}"
            end

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end

Sidekiq::Options[:cron_poll_interval] = 10

# initialize cron jobs. Each cron names its timezone explicitly: without it
# sidekiq-cron uses the container's local TZ (Asia/Kolkata), which shifted every
# job by 5.5h when the times were written as UTC.
unless ENV['SECRET_KEY_BASE_DUMMY']
  begin
    Sidekiq::Cron::Job.create(
      name:  'RebuildSitemapJob - daily 1am IST',
      cron:  '0 1 * * * Asia/Kolkata',
      class: 'RebuildSitemapJob'
    )

    Sidekiq::Cron::Job.create(
      name:  'RebuildCategoriesCacheJob - daily 3am IST',
      cron:  '0 3 * * * Asia/Kolkata',
      class: 'RebuildCategoriesCacheJob'
    )

    Sidekiq::Cron::Job.create(
      name:  'ExpungeEsDeletesJob - weekly Sun 2am IST',
      cron:  '0 2 * * 0 Asia/Kolkata',
      class: 'ExpungeEsDeletesJob'
    )

    Sidekiq::Cron::Job.create(
      name:  'InfraHealthCheckJob - daily 6am IST',
      cron:  '0 6 * * * Asia/Kolkata',
      class: 'InfraHealthCheckJob'
    )

    puts "Sidekiq Redis connection"
    Sidekiq.redis(&:ping)
  rescue StandardError => e
    puts "Sidekiq Redis connection note: #{e.message}"
  end
end
