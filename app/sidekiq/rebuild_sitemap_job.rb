class RebuildSitemapJob
  include Sidekiq::Job

  def perform(*args)
    Telemetry::Tracer.in_span('cron.rebuild_sitemap') do
      # Google and Bing retired their sitemap ping endpoints (the ping 404s);
      # search engines pick the sitemap up from robots.txt / Search Console.
      success = system 'bundle exec rake sitemap:refresh:no_ping'
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
