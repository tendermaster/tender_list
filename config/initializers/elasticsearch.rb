# frozen_string_literal: true

# Elasticsearch client initializer
# Configure connection to Elasticsearch cluster

require 'elasticsearch'

ElasticClient = Elasticsearch::Client.new(
  hosts: [ENV.fetch('ELASTICSEARCH_HOST', 'http://localhost:9200')],
  user: ENV.fetch('ELASTICSEARCH_USER', nil),
  password: ENV.fetch('ELASTICSEARCH_PASSWORD', nil),
  transport_options: {
    request: { timeout: 30 }
  },
  log: Rails.env.development?
)

# Verify connection on boot (optional, can be disabled in production)
if Rails.env.development?
  begin
    info = ElasticClient.info
    Rails.logger.info "Elasticsearch connected: #{info['version']['number']}"
  rescue Faraday::ConnectionFailed => e
    Rails.logger.warn "Elasticsearch not available: #{e.message}"
  end
end
