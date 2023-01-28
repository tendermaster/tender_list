# require 'elasticsearch/model'
class Tender < ApplicationRecord
  # include Elasticsearch::Model
  # include Elasticsearch::Model::Callbacks
  has_many :attachments
  searchkick
  extend Pagy::Searchkick
end

