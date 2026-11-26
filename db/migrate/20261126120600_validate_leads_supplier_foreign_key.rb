class ValidateLeadsSupplierForeignKey < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :leads, :suppliers
  end
end
