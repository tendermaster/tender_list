class RebuildCategoriesCacheJob
  include Sidekiq::Job

  def perform(*args)
    CategoryService.rebuild_categories_cache
  end

end

# every-day-at-2am
# Sidekiq::Cron::Job.create(name: 'RebuildCategoriesCacheJob - every-day-at-2am', cron: '0 2 * * *', class: 'RebuildCategoriesCacheJob')
# Sidekiq::Cron::Job.create(name: 'RebuildCategoriesCacheJob - every-day-at-1:30 ist', cron: '0 20 * * *', class: 'RebuildCategoriesCacheJob')
# 8pm utc - 1:30am
# sidekiq in ist
# Sidekiq::Cron::Job.create(name: 'RebuildCategoriesCacheJob - every-day-at-1 ist', cron: '0 1 * * *', class: 'RebuildCategoriesCacheJob')
