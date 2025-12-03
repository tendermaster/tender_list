if Rails.env.development?
  redis_host = '127.0.0.1'
  redis_password = ''
end

if Rails.env.production?
  redis_host = ENV['REDIS_HOST']
  redis_password = ENV['REDIS_PASSWORD']
end

redis_port = 6379
redis_db_sessions = 0

Rails.application.config.session_store :redis_session_store,
  key: '_sigmatenders_session',
  redis: {
    expire_after: 90.days, # Cookie expiration
    ttl: 90.days, # Redis expiration, defaults to expire_after
    key_prefix: 'sigmatenders:session:',
    url: "redis://:#{redis_password}@#{redis_host}:#{redis_port}/#{redis_db_sessions}",
  }
