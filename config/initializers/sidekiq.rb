# frozen_string_literal: true

redis_password = Rails.env == 'development' ? '' : ENV['REDIS_PASSWORD']
redis_host = Rails.env == 'development' ? '127.0.0.1' : 'redis'
redis_port = 6379
redis_db = 2

Sidekiq.configure_server do |config|
  config.redis = { url: "redis://:#{redis_password}@#{redis_host}:#{redis_port}/#{redis_db}" }
end

Sidekiq.configure_client do |config|
  config.redis = { url: "redis://:#{redis_password}@#{redis_host}:#{redis_port}/#{redis_db}" }
end

Sidekiq::Options[:cron_poll_interval] = 10

# initialize cron
# Sidekiq::Cron::Job.create(name: 'MailerJob - every min', cron: '* * * * *', class: 'MailerJob') # execute at every min
