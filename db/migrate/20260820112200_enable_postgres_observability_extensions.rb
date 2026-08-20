# frozen_string_literal: true

class EnablePostgresObservabilityExtensions < ActiveRecord::Migration[7.0]
  def change
    enable_extension 'pg_stat_statements'
    enable_extension 'pg_buffercache'
  end
end
