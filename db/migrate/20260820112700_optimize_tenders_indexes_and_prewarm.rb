# frozen_string_literal: true

class OptimizeTendersIndexesAndPrewarm < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    # 1. Enable pg_prewarm for in-memory buffer warming
    enable_extension 'pg_prewarm'

    # 2. Drop duplicate index on submission_close_date (keeps index_tenders_on_submission_close_date)
    remove_index :tenders, name: :index_submission_close_date_idx, if_exists: true

    # 3. Drop unused indexes with 0 lifetime scans
    remove_index :tenders, name: :index_tenders_on_created_at, if_exists: true
    remove_index :tenders, name: :index_tenders_on_emd, if_exists: true
    remove_index :tenders, name: :idx_tenders_source_close_date, if_exists: true
    remove_index :tenders, name: :index_tenders_on_bid_result_status, if_exists: true
    remove_index :tenders, name: :index_tenders_on_tender_value, if_exists: true
  end
end
