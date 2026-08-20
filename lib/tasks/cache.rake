# frozen_string_literal: true

namespace :cache do
  desc "Display Redis cache statistics and key prefix breakdown"
  task stats: :environment do
    puts "\n" + "=" * 60
    puts "📊 REDIS APPLICATION CACHE STATS (DB 2)"
    puts "=" * 60
    stats = CacheManager.stats
    puts "Total Keys   : #{stats[:total_keys]}"
    puts "Memory Used  : #{stats[:memory_used]}"
    puts "Memory Peak  : #{stats[:memory_peak]}"
    puts "\nKey Breakdown by Prefix:"
    puts "-" * 60
    stats[:breakdown].sort_by { |_k, v| -v }.each do |prefix, count|
      puts "  %-30s : %8d keys" % [prefix, count]
    end
    puts "=" * 60 + "\n"
  end

  desc "Clear search query snapshots, MLT similar tenders, and search counts"
  task clear_search: :environment do
    puts "Purging search, MLT, and count snapshots..."
    result = CacheManager.clear_search_cache
    puts "  Search Snapshots Purged : #{result[:search_snapshots]}"
    puts "  MLT Snapshots Purged    : #{result[:mlt_snapshots]}"
    puts "  Search Counts Purged    : #{result[:search_counts]}"
    puts "✅ Total Search Keys Purged: #{result[:total_purged]}"
  end

  desc "Clear cached tender detail pages (pass ID to clear single: rake cache:clear_tenders[123])"
  task :clear_tenders, [:tender_id] => :environment do |_t, args|
    tender_id = args[:tender_id]
    if tender_id.present?
      puts "Purging cache for tender ID #{tender_id}..."
    else
      puts "Purging cache for all tender detail records..."
    end
    result = CacheManager.clear_tender_cache(tender_id)
    puts "✅ Tender Keys Purged: #{result[:tender_keys_purged]}"
  end

  desc "Clear cached category keywords and taxonomy lists"
  task clear_categories: :environment do
    puts "Purging category cache..."
    result = CacheManager.clear_category_cache
    puts "✅ Category Keys Purged: #{result[:category_keys_purged]}"
  end

  desc "Clear all keys in Rails application cache (DB 2 only)"
  task clear_all: :environment do
    puts "Flushing entire Rails application cache (DB 2)..."
    result = CacheManager.clear_all
    puts "✅ #{result[:message]}"
  end
end
