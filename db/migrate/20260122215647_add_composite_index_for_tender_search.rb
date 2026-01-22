# frozen_string_literal: true

class AddCompositeIndexForTenderSearch < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    # Composite partial index for the UNION-based search strategy.
    # This index helps both Active and Inactive branches by:
    #   1. Filtering on is_visible = true (partial index condition)
    #   2. Efficiently partitioning by submission_close_date
    #
    # The CONCURRENTLY option prevents table locks during index creation on 10M+ rows.
    add_index :tenders,
              [:is_visible, :submission_close_date],
              where: "is_visible = true",
              name: "idx_tenders_visible_active_status",
              algorithm: :concurrently,
              if_not_exists: true
  end
end
