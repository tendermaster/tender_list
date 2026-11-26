module Marketplace
  # The marketplace.* views products-web reads (db/marketplace/views.sql).
  # schema.rb doesn't keep views, so migrations and the test setup apply them.
  module Views
    SQL = Rails.root.join('db/marketplace/views.sql')
    CONTRACT = Rails.root.join('db/marketplace/contract.json')

    def self.apply!(connection = ActiveRecord::Base.connection) = connection.execute(SQL.read)

    # { "marketplace.categories" => [["id", "bigint"], ...] }: what the
    # contract file records and products-web's generated types follow
    def self.columns(connection = ActiveRecord::Base.connection)
      rows = connection.select_rows(<<~SQL)
        SELECT table_name, column_name, data_type
        FROM information_schema.columns
        WHERE table_schema = 'marketplace'
        ORDER BY table_name, ordinal_position
      SQL
      rows.group_by(&:first).to_h { |table, cols| ["marketplace.#{table}", cols.map { _1.drop(1) }] }
    end

    def self.dump_contract! = CONTRACT.write("#{JSON.pretty_generate(columns)}\n")
  end
end
