namespace :bis do
  # bin/rails "bis:import[granted]"  this month's new licences
  # bin/rails "bis:import[all]"      every licence: ~176 MB, run once, at a quiet hour
  # bin/rails "bis:import[all,/tmp/bis-1016.html]"  from a page saved earlier
  desc 'Import BIS licences for the marketplace standards (Bis::Standards)'
  task :import, %i[report file] => :environment do |_task, args|
    report = (args[:report] || 'granted').to_sym
    rows = if args[:file]
             Bis::ReportClient.parse_report(File.read(args[:file], encoding: 'UTF-8'))
           else
             Bis::ReportClient.new(read_timeout: report == :all ? 1800 : 300).rows(report)
           end
    status_only = %i[suspended cancelled expired].include?(report)
    puts "#{rows.size} rows; #{Bis::LicenceImporter.new.import(rows, status_only:)}"
    puts "pages: #{Marketplace::PageRefresher.call}"
  end
end
