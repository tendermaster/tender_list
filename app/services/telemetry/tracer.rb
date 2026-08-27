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
          tracer.in_span(name, attributes: sanitize_attributes(attributes)) do |span|
            yield span if block_given?
          end
        else
          yield nil if block_given?
        end
      rescue StandardError => e
        record_exception(e)
        raise e
      end

      # Record an exception to the current active span and Sentry
      def record_exception(exception)
        Sentry.capture_exception(exception) if defined?(Sentry)

        return unless enabled? && defined?(OpenTelemetry)

        span = OpenTelemetry::Trace.current_span
        return unless span&.recording?

        span.record_exception(exception)
        span.status = OpenTelemetry::Trace::Status.error(exception.message)
      end

      def enabled?
        ENV['OTEL_ENABLED'] == 'true'
      end

      private

      # Sanitizes attributes to comply with OpenTelemetry Specification
      # Allows String, Numeric, Boolean, and Arrays of primitives
      def sanitize_attributes(attrs)
        attrs.each_with_object({}) do |(k, v), acc|
          acc[k.to_s] = case v
                        when String, Integer, Float, TrueClass, FalseClass
                          v
                        when Symbol
                          v.to_s
                        when Array
                          v.map { |elem| elem.is_a?(Symbol) ? elem.to_s : elem }
                        else
                          v.to_s
                        end
        end
      end
    end
  end
end
