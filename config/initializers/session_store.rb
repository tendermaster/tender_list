# https://stackoverflow.com/questions/5860950/setting-session-timeout-in-rails-3
# https://api.rubyonrails.org/v7.1/classes/ActionDispatch/Session/CookieStore.html
#
Rails.application.config.session_store :redis_session_store,
  key: '_sigmatenders_session',
  redis: {
    expire_after: 90.days, # Cookie expiration
    ttl: 90.days, # Redis expiration, defaults to expire_after
    key_prefix: 'sigmatenders:session:',
    url: 'redis://localhost:6379/0',
  }
