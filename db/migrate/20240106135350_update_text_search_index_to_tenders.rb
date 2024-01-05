class UpdateTextSearchIndexToTenders < ActiveRecord::Migration[7.0]
  def up
    remove_column :tenders, :tender_text_vector
    execute <<~SQL
            -- tender vector
            ALTER TABLE tenders
                ADD COLUMN tender_text_vector tsvector
                    GENERATED ALWAYS AS (to_tsvector(
                            'english',
                            coalesce(tender_id, '') || ' ' ||
                            coalesce(title, '') || ' ' ||
                            coalesce(description, '') || ' ' ||
                            coalesce(organisation, '') || ' ' ||
                            coalesce(state, '') || ' ' ||
                            coalesce(slug_uuid, '') || ' ' ||
                            coalesce(page_link, '') || ' ' ||
                            coalesce(tender_category, '') || ' ' ||
                            coalesce(tender_contract_type, '') || ' ' ||
                            coalesce(tender_source, '') || ' ' ||
                            coalesce(tender_reference_number, '') || ' '
                        )) STORED;
      CREATE INDEX tender_text_vector_idx ON tenders USING GIN (tender_text_vector);
    SQL
  end

  def down
    remove_column :tenders, :tender_text_vector
  end
end
