redis_host = ENV.fetch('REDIS_HOST', '127.0.0.1')
redis_password = ENV['REDIS_PASSWORD']

redis_port = 6379
redis_db_sessions = 1

redis_url = if redis_password.present?
              "redis://:#{redis_password}@#{redis_host}:#{redis_port}/#{redis_db_sessions}"
            else
              "redis://#{redis_host}:#{redis_port}/#{redis_db_sessions}"
            end

# Rails' built-in cache-backed session store (replaced the unmaintained
# redis-rails / redis-store gems). "session_v2" keeps these keys apart from the
# old redis-store "session:*" keys, which are in a different format and simply
# expire.
Rails.application.config.session_store :cache_store,
  cache: ActiveSupport::Cache::RedisCacheStore.new(url: redis_url, namespace: 'session_v2', expires_in: 14.days),
  expire_after: 14.days,
  key: '_sigmatenders_session',
  secure: Rails.env.production?,
  same_site: :lax # the session cookie doesn't inherit cookies_same_site_protection
