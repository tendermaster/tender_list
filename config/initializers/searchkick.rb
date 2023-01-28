# frozen_string_literal: true


# https://github.com/ankane/searchkick/issues/1531
Searchkick.client = Elasticsearch::Client.new host: 'http://elastic:changeme@localhost:9200'
# Elasticsearch::Client.new host: 'http://elastic:changeme@localhost:9200'
#


