# frozen_string_literal: true

module Telemetry
  class Tracer
    class << self
      # Wraps code execution inside an OpenTelemetry span with attributes
      # Usage:
      #   Telemetry::Tracer.in_span('tender.search', { query: 'road' }) do |span|
      #     # business logic
      #   end
      def in_span(name, attributes = {})
        if enabled? && defined?(OpenTelemetry)
          tracer = OpenTelemetry.tracer_provider.tracer('sigmatenders')
          tracer.in_span(name, attributes: stringify_attributes(attributes)) do |span|
            yield span if block_given?
          end
        else
          yield nil if block_given?
        end
      rescue StandardError => e
        record_exception(e)
        raise e
      end

      # Record an exception to the current active span
      def record_exception(exception)
        return unless enabled? && defined?(OpenTelemetry)

        span = OpenTelemetry::Trace.current_span
        return unless span.recording?

        span.record_exception(exception)
        span.status = OpenTelemetry::Trace::Status.error(exception.message)
      end

      def enabled?
        ENV['OTEL_ENABLED'] == 'true'
      end

      private

      def stringify_attributes(attrs)
        attrs.transform_keys(&:to_s).transform_values(&:to_s)
      end
    end
  end
end
