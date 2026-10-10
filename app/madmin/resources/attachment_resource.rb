class AttachmentResource < Madmin::Resource
  # 151k rows: extracted file_text is large, so it's detail-only and not searched.
  attribute :id, form: false
  attribute :file_name
  attribute :download_status
  attribute :tender
  attribute :created_at, form: false
  attribute :file_path, index: false
  attribute :download_link, index: false, searchable: false
  attribute :file_text, index: false, searchable: false
  attribute :updated_at, index: false, form: false
  # file_text_vector (search index) is never shown.

  def self.display_name(record) = record.file_name

  def self.default_sort_column = 'id'
end
