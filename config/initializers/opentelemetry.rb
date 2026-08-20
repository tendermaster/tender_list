# frozen_string_literal: true

# OpenTelemetry Instrumentation Bootstrap
# Toggle via OTEL_ENABLED="true" in environment or docker-compose.yml

if ENV['OTEL_ENABLED'] == 'true'
  begin
    require 'opentelemetry/sdk'
    require 'opentelemetry/exporter/otlp'
    require 'opentelemetry/instrumentation/rails'
    require 'opentelemetry/instrumentation/pg'
    require 'opentelemetry/instrumentation/redis'
    require 'opentelemetry/instrumentation/sidekiq'
    require 'opentelemetry/instrumentation/faraday'
    require 'opentelemetry/instrumentation/net/http'

    OpenTelemetry::SDK.configure do |c|
      c.service_name = ENV.fetch('OTEL_SERVICE_NAME', 'sigmatenders-rails')
      c.service_version = '1.0.0'

      # Standard lean instrumentation for core stack
      c.use 'OpenTelemetry::Instrumentation::Rails'
      c.use 'OpenTelemetry::Instrumentation::PG'
      c.use 'OpenTelemetry::Instrumentation::Redis'
      c.use 'OpenTelemetry::Instrumentation::Sidekiq'
      c.use 'OpenTelemetry::Instrumentation::Faraday'
      c.use 'OpenTelemetry::Instrumentation::Net::HTTP'
    end

    Rails.logger.info("🔭 OpenTelemetry initialized successfully for #{ENV.fetch('OTEL_SERVICE_NAME', 'sigmatenders-rails')}")
  rescue LoadError => e
    Rails.logger.warn("⚠️ OpenTelemetry gems not installed or disabled: #{e.message}")
  end
end
