class AddtenderRefenceNumberToTenders < ActiveRecord::Migration[7.0]
  def change
    add_column :tenders, :tender_reference_number, :string
    add_column :tenders, :location, :jsonb

    add_column :users, :role, :string, default: 'USER'
    add_column :users, :current_plan, :string, default: 'FREE'

    add_column :queries, :updates, :string, default: 'WEEKLY'
    add_column :queries, :last_sent, :datetime
    change_column_default :queries, :last_sent, -> { 'CURRENT_TIMESTAMP' }

    add_index :tenders, :tender_reference_number
    add_index :tenders, :submission_close_date
    add_index :tenders, :is_visible
    add_index :tenders, :created_at
    add_index :tenders, :emd
    add_index :tenders, :tender_value

    change_column_default :tenders, :created_at, -> { 'CURRENT_TIMESTAMP' }
  end

end
