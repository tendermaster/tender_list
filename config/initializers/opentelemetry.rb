# frozen_string_literal: true

# OpenTelemetry Instrumentation Bootstrap
# Enabled via OTEL_ENABLED="true" in .env / docker-compose.yml
# Native Elasticsearch OpenTelemetry is configured directly in config/initializers/elasticsearch.rb

if ENV['OTEL_ENABLED'] == 'true'
  begin
    require 'opentelemetry/sdk'

    # Samples every Sidekiq job (consumer spans), and everything else with the
    # sampler it wraps (OTEL_TRACES_SAMPLER, 2% of requests). Only a few jobs
    # run each day, so at the request ratio almost none were ever traced.
    class OtelJobsAlwaysSampled
      SAMPLED = OpenTelemetry::SDK::Trace::Samplers::Decision::RECORD_AND_SAMPLE

      def initialize(fallback)
        @fallback = fallback
      end

      def should_sample?(trace_id:, parent_context:, links:, name:, kind:, attributes:)
        if kind == :consumer
          tracestate = OpenTelemetry::Trace.current_span(parent_context).context.tracestate
          return OpenTelemetry::SDK::Trace::Samplers::Result.new(decision: SAMPLED, tracestate:)
        end

        @fallback.should_sample?(trace_id:, parent_context:, links:, name:, kind:, attributes:)
      end

      def description = "OtelJobsAlwaysSampled{#{@fallback.description}}"
    end

    require 'opentelemetry/exporter/otlp'
    require 'opentelemetry/instrumentation/rails'
    require 'opentelemetry/instrumentation/pg'
    require 'opentelemetry/instrumentation/redis'
    require 'opentelemetry/instrumentation/sidekiq'
    require 'opentelemetry/instrumentation/faraday'
    require 'opentelemetry/instrumentation/net/http'

    # Force protocol to http/protobuf for OTLP exporter compatibility
    ENV['OTEL_EXPORTER_OTLP_PROTOCOL'] = 'http/protobuf'
    ENV['OTEL_EXPORTER_OTLP_TRACES_PROTOCOL'] = 'http/protobuf'

    OpenTelemetry::SDK.configure do |c|
      c.service_name = ENV.fetch('OTEL_SERVICE_NAME', 'sigmatenders-rails')
      c.service_version = '1.0.0'

      # Standard lean instrumentation for core stack
      # 'Rails' only bundles the gems below (its install is a no-op), so each one
      # has to be enabled. ActionPack also inserts the Rack middleware that
      # creates the request root span; without it no request spans existed.
      c.use 'OpenTelemetry::Instrumentation::Rails'
      c.use 'OpenTelemetry::Instrumentation::ActionPack'
      c.use 'OpenTelemetry::Instrumentation::ActionView'
      c.use 'OpenTelemetry::Instrumentation::PG'
      # Only trace Redis calls inside a request/job trace; root-level calls were
      # the bulk of all spans and couldn't be tied to anything.
      c.use 'OpenTelemetry::Instrumentation::Redis', { trace_root_spans: false }
      c.use 'OpenTelemetry::Instrumentation::Sidekiq'
      c.use 'OpenTelemetry::Instrumentation::Faraday'
      # Sentry's own uploads are not app traffic.
      c.use 'OpenTelemetry::Instrumentation::Net::HTTP', { untraced_hosts: [/\.sentry\.io\z/] }
    end

    # Every background job is traced; requests keep the OTEL_TRACES_SAMPLER ratio
    OpenTelemetry.tracer_provider.sampler = OtelJobsAlwaysSampled.new(OpenTelemetry.tracer_provider.sampler)

    Rails.logger.info("🔭 OpenTelemetry initialized successfully for #{ENV.fetch('OTEL_SERVICE_NAME', 'sigmatenders-rails')}")
  rescue LoadError => e
    Rails.logger.warn("⚠️ OpenTelemetry gems not installed or disabled: #{e.message}")
  end
end
