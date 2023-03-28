# require 'elasticsearch/model'
class Tender < ApplicationRecord
  has_many :attachments

end
