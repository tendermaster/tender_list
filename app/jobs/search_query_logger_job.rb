# frozen_string_literal: true

class SearchQueryLoggerJob < ApplicationJob
  queue_as :default

  def perform(query)
    return if query.blank?

    clean_query = query.to_s.strip.truncate(255)
    return if clean_query.blank?

    SearchQuery.create(query: clean_query)
  rescue StandardError => e
    Rails.logger.warn("SearchQueryLoggerJob failed: #{e.message}")
  end
end
