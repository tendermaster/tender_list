# frozen_string_literal: true

module Telemetry
  class Metrics
    class << self
      # Record search query telemetry
      def record_search(query:, hits:, cache_hit:, duration_ms:)
        return unless Telemetry::Tracer.enabled?

        Telemetry::Tracer.in_span('telemetry.search_metric', {
          'search.query' => query.to_s,
          'search.hits' => hits.to_i,
          'search.cache_hit' => cache_hit ? 'true' : 'false',
          'search.duration_ms' => duration_ms.to_f.round(2)
        })
      end

      # Record cache event
      def record_cache_event(operation:, key:, hit:)
        return unless Telemetry::Tracer.enabled?

        Telemetry::Tracer.in_span('telemetry.cache_event', {
          'cache.operation' => operation.to_s,
          'cache.key_prefix' => key.to_s.split(':').first,
          'cache.hit' => hit ? 'true' : 'false'
        })
      end
    end
  end
end
