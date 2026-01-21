redis_host = ENV.fetch('REDIS_HOST', '127.0.0.1')
redis_password = ENV['REDIS_PASSWORD']

redis_port = 6379
redis_db_sessions = 0

redis_url = if redis_password.present?
              "redis://:#{redis_password}@#{redis_host}:#{redis_port}/#{redis_db_sessions}/session"
            else
              "redis://#{redis_host}:#{redis_port}/#{redis_db_sessions}/session"
            end

Rails.application.config.session_store :redis_store,
  servers: [redis_url],
  expire_after: 365.days,
  key: '_sigmatenders_session',
  threadsafe: true,
  secure: Rails.env.production?

begin
  puts "Session Redis connection"
  Redis.new(url: redis_url.gsub("/session", "")).ping
rescue StandardError => e
  puts "Session Redis connection failed: #{e.message}"
end