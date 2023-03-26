class BackgroundTaskJob
  include Sidekiq::Job

  def perform(*args)
    # Do something
    case args[0]
    when 'sitemap'
      # rake "-s sitemap:refresh"
      `rails sitemap:create`

    when 'elasticsearch'
      Tender.reindex(resume: true)
    end
  end
end
