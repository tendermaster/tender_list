# frozen_string_literal: true

class CacheManager
  class << self
    # Return cache statistics (keys count, memory usage, breakdown by prefix)
    def stats
      result = {
        total_keys: 0,
        memory_used: '0B',
        memory_peak: '0B',
        breakdown: Hash.new(0)
      }

      with_redis do |redis|
        info = redis_info(redis)
        result[:memory_used] = info['used_memory_human'] || 'N/A'
        result[:memory_peak] = info['used_memory_peak_human'] || 'N/A'

        cursor = '0'
        loop do
          cursor, keys = scan_keys(redis, cursor, match: '*', count: 500)
          result[:total_keys] += keys.size

          keys.each do |k|
            prefix = k.to_s.split(':').first
            result[:breakdown][prefix] += 1
          end

          break if cursor == '0' || cursor.nil?
        end
      end

      result
    end

    # Safely delete keys matching a pattern using non-blocking SCAN
    def purge_pattern(pattern)
      deleted_count = 0

      with_redis do |redis|
        cursor = '0'
        loop do
          cursor, keys = scan_keys(redis, cursor, match: pattern, count: 500)
          if keys.present?
            del_keys(redis, keys)
            deleted_count += keys.size
          end
          break if cursor == '0' || cursor.nil?
        end
      end

      deleted_count
    end

    # Clear only search queries, MLT, and search counts
    def clear_search_cache
      purged_search = purge_pattern('search:*')
      purged_mlt = purge_pattern('mlt:*')
      purged_count = purge_pattern('search_count:*')
      
      {
        search_snapshots: purged_search,
        mlt_snapshots: purged_mlt,
        search_counts: purged_count,
        total_purged: purged_search + purged_mlt + purged_count
      }
    end

    # Clear tender detail cache (for a specific ID or all tenders)
    def clear_tender_cache(tender_id = nil)
      pattern = tender_id.present? ? "tender:#{tender_id}:*" : 'tender:*'
      purged = purge_pattern(pattern)
      { tender_keys_purged: purged }
    end

    # Clear cached category lists
    def clear_category_cache
      purged = purge_pattern('category:*') + purge_pattern('category_keyword_present:*')
      { category_keys_purged: purged }
    end

    # Clear all Rails application cache (DB 2 only)
    def clear_all
      Rails.cache.clear
      { message: 'Rails application cache cleared successfully.' }
    end

    private

    def with_redis(&block)
      if Rails.cache.respond_to?(:redis) && Rails.cache.redis.present?
        conn = Rails.cache.redis
        if conn.respond_to?(:then)
          conn.then(&block)
        elsif conn.respond_to?(:with)
          conn.with(&block)
        else
          yield conn
        end
      else
        yield Redis.new
      end
    end

    def scan_keys(redis, cursor, match:, count: 500)
      if redis.respond_to?(:call)
        cursor, keys = redis.call('scan', cursor, 'match', match, 'count', count)
        [cursor.to_s, Array(keys)]
      elsif redis.respond_to?(:scan)
        cursor, keys = redis.scan(cursor, match: match, count: count)
        [cursor.to_s, Array(keys)]
      else
        ['0', []]
      end
    end

    def del_keys(redis, keys)
      return if keys.blank?
      if redis.respond_to?(:call)
        redis.call('del', *keys)
      elsif redis.respond_to?(:del)
        redis.del(*keys)
      end
    end

    def redis_info(redis)
      info_str = if redis.respond_to?(:call)
                   redis.call('info', 'memory').to_s
                 elsif redis.respond_to?(:info)
                   redis.info('memory')
                 else
                   {}
                 end

      return info_str if info_str.is_a?(Hash)

      info_str.to_s.each_line.with_object({}) do |line, h|
        next unless line.include?(':')
        k, v = line.strip.split(':', 2)
        h[k] = v
      end
    end
  end
end
