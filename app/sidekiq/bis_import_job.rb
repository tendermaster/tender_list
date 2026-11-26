# Monthly: new BIS licences (report 1015) and status changes (suspended,
# cancelled, expired), for the standards in Bis::Standards, then the
# marketplace pages. One report at a time, with a pause between, to go easy
# on BIS. The first full load is a one-off: bin/rails "bis:import[all]".
class BisImportJob
  include Sidekiq::Job
  sidekiq_options retry: 2

  PAUSE = 30 # seconds between reports

  def perform
    client = Bis::ReportClient.new
    importer = Bis::LicenceImporter.new
    { granted: false, suspended: true, cancelled: true, expired: true }.each_with_index do |(report, status_only), i|
      sleep PAUSE if i.positive?
      result = importer.import(client.rows(report), status_only:)
      Rails.logger.info("BIS import #{report}: #{result}")
    end
    Rails.logger.info("Marketplace pages: #{Marketplace::PageRefresher.call}")
  end
end
