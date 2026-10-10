# frozen_string_literal: true

# Scrapers look tenders up by exact title (e.g. stage4_psu_results.js
# `where({ title })`); without an index each call scanned the whole 21GB table
# (~80s). A hash index serves equality only and is far smaller than a btree
# on long titles.
class AddTitleHashIndexToTenders < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_index :tenders, :title, using: :hash, algorithm: :concurrently, if_not_exists: true
  end
end
