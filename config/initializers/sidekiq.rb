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

# initialize cron
# Sidekiq::Cron::Job.create(name: 'MailerJob - every min', cron: '* * * * *', class: 'MailerJob') # execute at every min

begin
  puts "Sidekiq Redis connection"
  Sidekiq.redis(&:ping)
rescue Redis::ConnectionError
  raise "Sidekiq Redis connection failed"
end
