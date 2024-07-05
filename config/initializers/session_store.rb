# https://stackoverflow.com/questions/5860950/setting-session-timeout-in-rails-3
# https://api.rubyonrails.org/v7.1/classes/ActionDispatch/Session/CookieStore.html
#
Rails.application.config.session_store :active_record_store, :key => '_sigmatenders_session', expire_after: 90.days
