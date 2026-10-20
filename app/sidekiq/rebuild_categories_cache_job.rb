class RebuildCategoriesCacheJob
  include Sidekiq::Job

  def perform(*args)
    Telemetry::Tracer.in_span('cron.rebuild_categories_cache') do
      # ~42k keyword checks, each a cache read and often a search: the job's
      # span keeps the total time without a span for each
      Telemetry::Tracer.untraced { CategoryService.rebuild_categories_cache }
    end
  end

end

# every-day-at-2am
# Sidekiq::Cron::Job.create(name: 'RebuildCategoriesCacheJob - every-day-at-2am', cron: '0 2 * * *', class: 'RebuildCategoriesCacheJob')
# Sidekiq::Cron::Job.create(name: 'RebuildCategoriesCacheJob - every-day-at-1:30 ist', cron: '0 20 * * *', class: 'RebuildCategoriesCacheJob')
# 8pm utc - 1:30am
# sidekiq in ist
# Sidekiq::Cron::Job.create(name: 'RebuildCategoriesCacheJob - every-day-at-1 ist', cron: '0 1 * * *', class: 'RebuildCategoriesCacheJob')
