class Query < ApplicationRecord
  belongs_to :user

  before_validation :normalize_keywords

  validates :name, length: { minimum: 1 }
  validates :include_keyword, presence: true
  validates :updates, inclusion: ['REGULARLY', 'WEEKLY', 'MONTHLY', 'NONE']

  def self.find_by_keyword_or_name(term)
    return nil if term.blank?

    term_clean = term.to_s.strip.downcase
    where('LOWER(name) = ?', term_clean).first ||
      where("LOWER(REPLACE(name, ' ', '-')) = ?", term_clean).first
  end

  def include_keywords_array
    include_keyword.to_s.split(',').map { |e| e.gsub(/[()]/, '').strip }.reject(&:blank?)
  end

  def exclude_keywords_array
    exclude_keyword.to_s.split(',').map { |e| e.gsub(/[()]/, '').strip }.reject(&:blank?)
  end

  def to_search_query
    includes = include_keywords_array.map { |e| "(#{e})" }
    excludes = exclude_keywords_array.map { |e| "-(#{e.gsub(' ', '\\ ')})" }

    [includes.join(' | '), excludes.join(' ')].reject(&:blank?).join(' ')
  end

  private

  def normalize_keywords
    self.include_keyword = include_keywords_array.join(', ') if include_keyword.present?
    self.exclude_keyword = exclude_keywords_array.join(', ') if exclude_keyword.present?
  end

end
