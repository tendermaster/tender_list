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

Rails.application.config.session_store :redis_store,
  servers: ["redis://:#{redis_password}@#{redis_host}:#{redis_port}/#{redis_db_sessions}"],
  expire_after: 90.days,
  key: '_sigmatenders_session',
  threadsafe: true,
  secure: Rails.env.production?
