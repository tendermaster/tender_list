class RebuildSitemapJob
  include Sidekiq::Job

  def perform(*args)
    # Do something
    success = system 'bundle exec rake sitemap:create'
    if success
      p 'Sitemap created successfully'
    else
      p 'Sitemap could not be created'
    end
    nil
  end
end

# Sidekiq::Cron::Job.create(name: 'RebuildCategoriesCacheJob - every-day-at-1:30 ist', cron: '0 22 * * *', class: 'RebuildCategoriesCacheJob')
# 10pm utc - 3:30am
