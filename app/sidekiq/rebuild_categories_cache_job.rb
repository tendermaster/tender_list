class RebuildCategoriesCacheJob
  include Sidekiq::Job

  def perform(*args)
    CategoryService.rebuild_categories_cache
  end

end

# every-day-at-2am
# Sidekiq::Cron::Job.create(name: 'RebuildCategoriesCacheJob - every-day-at-2am', cron: '0 2 * * *', class: 'RebuildCategoriesCacheJob')
#
