# frozen_string_literal: true

class CustomQuery

  QUERY_LIST = {
    'ngo services': 75,
  }.freeze

  def self.custom_query?(query)
    query_id = QUERY_LIST[query.downcase.to_sym]
    if query_id.present?
      q = Query.find(query_id)
      if q.present?
        QueriesController.get_query_string(q)
      end
    end
  end
end
