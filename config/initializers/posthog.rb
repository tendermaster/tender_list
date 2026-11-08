# PostHog product analytics: server-side events from the controllers
# (ApplicationController#track) and identified users (User#posthog_properties),
# sent to PostHog US. Off unless POSTHOG_PROJECT_TOKEN and POSTHOG_HOST are
# set; without them PostHog.capture does nothing (tests, development).
#
# Errors stay in Sentry: PostHog's exception capture, ActiveJob
# instrumentation and Logs are left off.
require 'posthog'

token = ENV['POSTHOG_PROJECT_TOKEN'].to_s.strip
host = ENV['POSTHOG_HOST'].to_s.strip

if token.present? && host.present?
  PostHog.init do |config|
    config.api_key = token
    config.host = host
  end

  PostHog::Rails.configure do |config|
    config.auto_capture_exceptions = false
    config.report_rescued_exceptions = false
    config.auto_instrument_active_job = false
    config.logs_enabled = false
  end
end
