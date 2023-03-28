class AddTextSearchIndexToTenders < ActiveRecord::Migration[7.0]
  def up
    # add_column :attachments, :file_text_vector
    execute <<~SQL
            -- attachment vector
                  ALTER TABLE attachments
                      ADD COLUMN file_text_vector tsvector
                          GENERATED ALWAYS AS (
                              to_tsvector('english', attachments.file_text)
                              ) STORED;

          CREATE INDEX file_text_vector_idx ON attachments USING GIN (file_text_vector);

            -- tender vector
            ALTER TABLE tenders
                ADD COLUMN tender_text_vector tsvector
                    GENERATED ALWAYS AS (to_tsvector(
                            'english',
                            coalesce("tender_id", '') || ' ' ||
                            coalesce(title, '') || ' ' ||
                            coalesce(description, '') || ' ' ||
                            coalesce(organisation, '') || ' ' ||
                            coalesce(tender_category, '') || ' ' ||
                            coalesce(tender_contract_type, '') || ' '
                        )) STORED;
      CREATE INDEX tender_text_vector_idx ON tenders USING GIN (tender_text_vector);
    SQL
  end

  def down
    remove_column :attachments, :file_text_vector
    remove_column :tenders, :tender_text_vector
  end

end
