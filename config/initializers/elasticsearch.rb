# frozen_string_literal: true

# Elasticsearch client initializer
# Configure connection to Elasticsearch cluster

require 'elasticsearch'
require 'faraday/net_http_persistent'

ElasticClient = Elasticsearch::Client.new(
  hosts: [ENV.fetch('ELASTICSEARCH_HOST', 'http://localhost:9200')],
  user:ENV.fetch('ELASTICSEARCH_USER', nil),
  password: ENV.fetch('ELASTICSEARCH_PASSWORD', nil),
  opentelemetry: ENV['OTEL_ENABLED'] == 'true',
  opentelemetry_tracer_provider: (OpenTelemetry.tracer_provider if defined?(OpenTelemetry)),
  transport_options: {
    request: { timeout: 15, open_timeout: 5 }
  },
  retry_on_failure: false,      # don't compound timeout by retrying
  log: Rails.env.development?
) do |faraday|
  # Reuse TCP connections (per thread) instead of reconnecting on every call.
  # The 5s default idle timeout is shorter than the gap between one Puma
  # thread's requests, so connections were being dropped before reuse.
  faraday.adapter(:net_http_persistent) { |http| http.idle_timeout = 120 }
end

# Verify connection on boot (optional, can be disabled in production)
if Rails.env.development?
  begin
    info = ElasticClient.info
    Rails.logger.info "Elasticsearch connected: #{info['version']['number']}"
  rescue StandardError => e
    Rails.logger.warn "Elasticsearch not available: #{e.message}"
  end
end
