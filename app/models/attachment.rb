class Attachment < ApplicationRecord
  belongs_to :tender

  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "download_link", "download_status", "file_name", "file_path", "file_text", "file_text_vector", "id", "tender_id", "updated_at"]
  end

end
