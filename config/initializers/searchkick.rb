require 'elasticsearch'

ENV["ELASTICSEARCH_URL"] = ENV["ELASTICSEARCH_URL"].nil? ? "http://elastic:changeme@127.0.0.1:9200" : ENV["ELASTICSEARCH_URL"]

ElasticClient = Elasticsearch::Client.new
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
