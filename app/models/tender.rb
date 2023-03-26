# require 'elasticsearch/model'
class Tender < ApplicationRecord
  # include Elasticsearch::Model
  # include Elasticsearch::Model::Callbacks
  has_many :attachments

  searchkick mappings: {
    attachments: {
      properties: {
        name: { type: "string", index: "analzye", ignore_above: 256 }
      }
    }
  }

  def search_data
    {
      id:,
      tenderId:,
      title:,
      description:,
      organisation:,
      state:,
      tender_value:,
      tender_fee:,
      emd:,
      bid_open_date:,
      submission_open_date:,
      submission_close_date:,
      tender_search_data:,
      tender_category:,
      tender_contract_type:,
      attachments: attachments.map do |attachment|
        {
          id: attachment.id,
          file_text: attachment.file_text,
          file_name: attachment.file_name
        }
      end
      # attachment_text: attachments.map do |attachment|
      #   {
      #     id: attachment.id,
      #     file_text: attachment.file_text.chars.each_slice(30000).map(&:join),
      #     file_name: attachment.file_name
      #   }
      # end
    }
  end

  extend Pagy::Searchkick

end

# def split_text(text, number = 30000)
#   from = 0
#   to = number
#   text_array = []
#   (text.length / number).ceil.times do |number|
#     text_array.push(text[from..to])
#     from += number
#     to += number
#   end
#   text_array
# end
