# frozen_string_literal: true

redis_host = Rails.env == 'development' ? 'localhost' : 'redis'
redis_port = 6379
redis_db = 1

Sidekiq.configure_server do |config|
  config.redis = { url: "redis://#{redis_host}:#{redis_port}/#{redis_db}" }
end

Sidekiq.configure_client do |config|
  config.redis = { url: "redis://#{redis_host}:#{redis_port}/#{redis_db}" }
end

