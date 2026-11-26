require 'test_helper'

# Rows are made up, in BIS report format: never real licence data here
# (tender_list is a public repository)
class Bis::LicenceImporterTest < ActiveSupport::TestCase
  def row(**overrides)
    {
      'CML No' => '9900000001',
      'Firm Name & Address' => 'M/S EXAMPLE POLYMERS PVT LTD<BR><BR>ADDRESS:- PLOT 1, TEST ESTATE, SAMPLE NAGAR<BR>PINCODE:-700001',
      'District' => 'KOLKATA', 'State' => 'WEST BENGAL', 'Standard No' => 'IS 4984 : 2016',
      'Granted Date' => '2026-11-01', 'Validity Date' => '2027-10-31', 'Current Status' => 'Operative',
      'Variety' => 'PE 100 PN 6 DN 63 to 90 mm SDR 26', 'Brand' => 'EXAMPLEFLOW®,   ExampleFlow'
    }.merge(overrides)
  end

  test 'creates the supplier and licence, with parsed grades and slugs' do
    result = Bis::LicenceImporter.new.import([row])
    assert_equal 1, result.created

    supplier = Supplier.sole
    assert_equal 'EXAMPLE POLYMERS PVT LTD', supplier.name
    assert_equal 'PLOT 1, TEST ESTATE, SAMPLE NAGAR', supplier.address
    assert_equal '700001', supplier.pincode
    assert_equal ['Kolkata', 'West Bengal'], [supplier.district, supplier.state]
    assert_equal 'west-bengal', supplier.state_slug
    assert_equal 'example-polymers-pvt-ltd-kolkata', supplier.slug

    licence = BisLicence.sole
    assert_equal 'IS 4984', licence.is_number
    assert_equal ['EXAMPLEFLOW'], licence.brands
    assert_equal [63, 75, 90], licence.sizes_mm
    assert_equal({ 'brands' => ['exampleflow'], 'grades' => ['pn-6'] }, licence.slugs)
    assert licence.data_changed_at
  end

  test 'imports hand pumps (IS 15500), which have no sizes to match' do
    Bis::LicenceImporter.new.import([row('Standard No' => 'IS 15500 : PART 2 : 2019', 'Variety' => 'India Mark II, Deep well')])
    licence = BisLicence.sole
    assert_equal 'IS 15500', licence.is_number
    assert_equal [], licence.sizes_mm
  end

  test 'skips standards the marketplace does not list' do
    result = Bis::LicenceImporter.new.import([row('Standard No' => 'IS 1180 : PART 1 : 2014')])
    assert_equal 1, result.skipped
    assert_equal 0, BisLicence.count
  end

  test 'a second licence of the same firm joins its supplier; an unchanged row keeps its date' do
    Bis::LicenceImporter.new.import([row])
    changed_at = BisLicence.sole.data_changed_at
    travel 1.day do
      result = Bis::LicenceImporter.new.import([row, row('CML No' => '9900000002', 'Standard No' => 'IS 14333 : 2022')])
      assert_equal 1, result.created
      assert_equal 1, result.unchanged
    end
    assert_equal 1, Supplier.count
    assert_equal changed_at, BisLicence.find_by(cml_no: '9900000001').data_changed_at
  end

  test 'status reports change only licences already known' do
    Bis::LicenceImporter.new.import([row])
    result = Bis::LicenceImporter.new.import(
      [row('Current Status' => 'Suspended'), row('CML No' => '9900000009', 'Current Status' => 'Cancelled')],
      status_only: true
    )
    assert_equal 1, result.updated
    assert_equal 1, result.skipped
    assert_equal 'Suspended', BisLicence.sole.status
  end

  test 'reads rows from a report page' do
    html = "<script>\nvar jsonvalues = '#{[row].to_json.gsub("'", "\\\\'")}';\n</script>"
    assert_equal '9900000001', Bis::ReportClient.parse_report(html).sole['CML No']
    assert_raises(Bis::ReportClient::Error) { Bis::ReportClient.parse_report('<html></html>') }
  end
end
