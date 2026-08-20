class RebuildSitemapJob
  include Sidekiq::Job

  def perform(*args)
    Telemetry::Tracer.in_span('cron.rebuild_sitemap') do
      success = system 'bundle exec rake sitemap:refresh'
      if success
        Rails.logger.info 'Sitemap created successfully'
      else
        Rails.logger.error 'Sitemap could not be created'
      end
    end
    nil
  end
end

# Sidekiq::Cron::Job.create(name: 'RebuildSitemapJob - every-day-at-3 ist', cron: '0 3 * * *', class: 'RebuildSitemapJob')
