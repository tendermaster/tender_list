# frozen_string_literal: true

if Rails.env.development?
  redis_host = '127.0.0.1'
  redis_password = ''
end

if Rails.env.production?
  redis_host = ENV['REDIS_HOST']
  redis_password = ENV['REDIS_PASSWORD']
end

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
