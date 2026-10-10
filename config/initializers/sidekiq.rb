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

# initialize cron jobs (times in UTC, server runs UTC)
# IST = UTC+5:30  =>  1am IST = 19:30 UTC (prev day),  3am IST = 21:30 UTC
unless ENV['SECRET_KEY_BASE_DUMMY']
  begin
    Sidekiq::Cron::Job.create(
      name:  'RebuildSitemapJob - daily 1am IST',
      cron:  '30 19 * * *',   # 19:30 UTC = 01:00 IST
      class: 'RebuildSitemapJob'
    )

    Sidekiq::Cron::Job.create(
      name:  'RebuildCategoriesCacheJob - daily 3am IST',
      cron:  '30 21 * * *',   # 21:30 UTC = 03:00 IST
      class: 'RebuildCategoriesCacheJob'
    )

    Sidekiq::Cron::Job.create(
      name:  'ExpungeEsDeletesJob - weekly Sun 2am IST',
      cron:  '30 20 * * 6',   # Sat 20:30 UTC = Sun 02:00 IST
      class: 'ExpungeEsDeletesJob'
    )

    Sidekiq::Cron::Job.create(
      name:  'InfraHealthCheckJob - daily 6am IST',
      cron:  '30 0 * * *',    # 00:30 UTC = 06:00 IST
      class: 'InfraHealthCheckJob'
    )

    puts "Sidekiq Redis connection"
    Sidekiq.redis(&:ping)
  rescue StandardError => e
    puts "Sidekiq Redis connection note: #{e.message}"
  end
end
