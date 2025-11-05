require 'elasticsearch'
require 'uri'

# p ENV["ELASTICSEARCH_URL"]

# ENV["ELASTICSEARCH_URL"] = ENV["ELASTICSEARCH_URL"].nil? ? "http://elastic:changeme@127.0.0.1:9200" : ENV["ELASTICSEARCH_URL"]

# ElasticClient = Elasticsearch::Client.new url: ENV["ELASTICSEARCH_URL"]
# url = ENV["ELASTICSEARCH_URL"]
# ElasticClient = Elasticsearch::Client.new url: url

# ensure env is present
begin
  ENV.fetch('ELASTICSEARCH_HOST')
  ENV.fetch('ELASTICSEARCH_PORT')
  ENV.fetch('ELASTICSEARCH_USER')
  ENV.fetch('ELASTICSEARCH_PASSWORD')
rescue KeyError => e
  puts "Environment variable missing: #{e.message}"
  # Optionally, you can raise an error or exit the application here
  raise e
end

ElasticClient = Elasticsearch::Client.new(
  host: ENV['ELASTICSEARCH_HOST'] || 'elasticsearch',
  port: ENV['ELASTICSEARCH_PORT'] || '9200',
  user: ENV['ELASTICSEARCH_USER'] || 'elastic',
  password: ENV['ELASTICSEARCH_PASSWORD'] || 'changeme',
)

begin
  puts "Pinging Elasticsearch at #{ENV['ELASTICSEARCH_HOST']}:#{ENV['ELASTICSEARCH_PORT']}..."
  puts "Ping response: #{ElasticClient.ping}"
rescue => e
  puts "Elasticsearch connection error: #{e.message}"
end

# client.search(
#   index: 'search-v2-sigmatenders',
#   body: {
#     query: { match: { public_tenders_title: 'repair' } },
#     sort: [{
#              "public_tenders_submission_close_date": "desc"
#            }]
#   }
# )
# r = client.search(
#   index: 'search-v2-sigmatenders',
#   body: {
#     query: {
#       multi_match: {
#         query: 'repair',
#         "fields": ["public_tenders_tender_id", "public_tenders_title", "public_tenders_description", "public_tenders_organisation", "public_tenders_slug_uuid", "public_tenders_page_link", "public_tenders_state"]
#       }
#     },
#     sort: [{
#              "public_tenders_submission_close_date": "desc"
#            }],
#     size: 10,
#     from: 0
#   }
# )
