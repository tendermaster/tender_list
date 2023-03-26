# frozen_string_literal: true


# https://github.com/ankane/searchkick/issues/1531

elastic_host = Rails.env == 'development' ? 'localhost' : 'elasticsearch'

Searchkick.client = Elasticsearch::Client.new host: "http://elastic:changeme@#{elastic_host}:9200"
# Elasticsearch::Client.new host: 'http://elastic:changeme@localhost:9200'

redis_host = Rails.env == 'development' ? 'localhost' : 'redis'
redis_port = 6379
redis_db = 2

Searchkick.redis = Redis.new({ host: redis_host, port: redis_port, db: redis_db })

