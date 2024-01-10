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

# Sidekiq::Cron::Job.create(name: 'RebuildSitemapJob - every-day-at-3 ist', cron: '0 3 * * *', class: 'RebuildSitemapJob')
