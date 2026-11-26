module Bis
  # Upserts suppliers and licences from BIS report rows, for the standards in
  # Bis::Standards. A supplier is matched by name + PIN, a licence by its CML
  # number. data_changed_at moves only when status, brands or variety change,
  # so pages' lastmod means a real change.
  class LicenceImporter
    Result = Struct.new(:created, :updated, :unchanged, :skipped, keyword_init: true) do
      def to_s = "#{created} new, #{updated} changed, #{unchanged} unchanged, #{skipped} skipped"
    end

    def initialize(seen_on: Date.current)
      @seen_on = seen_on
      @result = Result.new(created: 0, updated: 0, unchanged: 0, skipped: 0)
    end

    # rows: report rows (Hashes). status_only: true for the suspended,
    # cancelled and expired reports, which only change licences already known.
    def import(rows, status_only: false)
      rows.each do |row|
        record = Record.new(row)
        if !record.valid? || !Standards.imported?(record.is_number)
          @result.skipped += 1
          next
        end
        status_only ? update_status(record) : upsert(record)
      end
      @result
    end

    private

    def update_status(record)
      licence = BisLicence.find_by(cml_no: record.cml_no)
      return @result.skipped += 1 if licence.nil?

      licence.assign_attributes(status: record.status, last_seen_on: @seen_on)
      save(licence)
    end

    def upsert(record)
      supplier = find_or_build_supplier(record)
      licence = BisLicence.find_or_initialize_by(cml_no: record.cml_no)
      licence.assign_attributes(
        supplier:, standard: record.standard, is_number: record.is_number, brands: record.brands,
        variety: record.variety, status: record.status, granted_on: record.granted_on,
        valid_until: record.valid_until, last_seen_on: @seen_on, raw: record.raw,
        grades: VarietyParser.parse(record.variety, sizes: Standards.sizes(record.is_number))
      )
      BisLicence.transaction do
        supplier.save! if supplier.new_record? || supplier.changed?
        save(licence)
      end
    end

    def find_or_build_supplier(record)
      key = Supplier.identity_key_for(record.name, record.pincode)
      supplier = Supplier.find_or_initialize_by(identity_key: key)
      supplier.assign_attributes(name: record.name, address: record.address, pincode: record.pincode,
                                 district: record.district, state: record.state)
      supplier
    end

    def save(licence)
      new_record = licence.new_record?
      shown_changed = licence.will_save_change_to_status? || licence.will_save_change_to_brands? ||
                      licence.will_save_change_to_variety?
      licence.data_changed_at = Time.current if new_record || shown_changed
      licence.save!
      if new_record then @result.created += 1
      elsif shown_changed then @result.updated += 1
      else @result.unchanged += 1
      end
    end
  end
end
