# A quote request can name the supplier it was sent from (a supplier's page)
class AddSupplierToLeads < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_reference :leads, :supplier, index: { algorithm: :concurrently }
    add_foreign_key :leads, :suppliers, validate: false
  end
end
