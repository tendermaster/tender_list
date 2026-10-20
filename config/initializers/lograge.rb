# frozen_string_literal: true

# Production: one JSON line per request instead of Rails' five (production.log
# was ~600 MB a day). Form parameters are left out, so leads' names and
# numbers don't land in the log.
Rails.application.configure do
  config.lograge.enabled = Rails.env.production?
  config.lograge.formatter = Lograge::Formatters::Json.new
  config.lograge.custom_payload do |controller|
    request = controller.request
    {
      time: Time.current.utc.iso8601(3),
      ip: request.remote_ip, # the visitor's, via Caddy (caddy/conf/Caddyfile)
      request_id: request.request_id,
      query: request.query_string.presence&.truncate(200),
      user_id: (controller.current_user&.id if controller.respond_to?(:current_user, true))
    }.compact
  end
end
