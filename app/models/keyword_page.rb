# The keywords behind a public keyword page (/tenders/Ngo-Services-tenders),
# kept by staff in /admin. Pages without one search for their own name.
# (They used to borrow any customer's saved search with the same name, so
# /tenders/West-Bengal-tenders showed one user's "Demolition tender".)
class KeywordPage < ApplicationRecord
  before_validation :normalize

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :include_keyword, presence: true

  # "Ngo Services" or "ngo-services" (the page's URL slug)
  def self.for(term)
    name = term.to_s.tr('-', ' ').squish.downcase
    find_by('LOWER(name) = ?', name) if name.present?
  end

  def include_keywords = split(include_keyword)
  def exclude_keywords = split(exclude_keyword)

  # Each keyword of several words is an exact phrase, so "capacity building"
  # doesn't find "10 Ton Capacity Body Building"
  def to_search_query
    includes = include_keywords.map { |k| k.include?(' ') ? %{("#{k}")} : "(#{k})" }
    excludes = exclude_keywords.map { |k| "-(#{k.gsub(' ', '\\ ')})" }
    [includes.join(' | '), excludes.join(' ')].compact_blank.join(' ')
  end

  def path = Rails.application.routes.url_helpers.keyword_tender_path(keyword: name.parameterize.titleize.tr(' ', '-'))

  private

  def split(keywords) = keywords.to_s.split(/[,\n]/).map { |k| k.gsub(/[()"|]/, ' ').squish }.compact_blank.uniq

  def normalize
    self.name = name.to_s.squish
    self.include_keyword = include_keywords.join(', ')
    self.exclude_keyword = exclude_keywords.join(', ').presence
  end
end
