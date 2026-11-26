# Made-up marketplace data for tests: never real suppliers here (tender_list
# is a public repository)
module MarketplaceHelper
  def marketplace_product(**attrs)
    Product.create!({
      name: 'HDPE Pipes', slug: 'hdpe-pipes', category: 'Water & Sanitation', summary: 'HDPE pipes',
      body: 'Guide', marketplace: true, is_numbers: ['IS 4984'], tender_query: 'hdpe pipe'
    }.merge(attrs))
  end

  # A supplier with one Operative licence (or the status given)
  def licensed_supplier(name, state: 'West Bengal', sizes: [63, 90], pn: [6], brands: ['Exampleflow'],
                        status: 'Operative', supplier_status: :listed, is_number: 'IS 4984')
    supplier = Supplier.create!(name:, identity_key: name.parameterize, address: '1 Test Road', pincode: '700001',
                                district: 'Kolkata', state:, status: supplier_status)
    supplier.bis_licences.create!(cml_no: "99#{SecureRandom.random_number(10**8)}", standard: "#{is_number} : 2016",
                                  is_number:, brands:, status:, grades: { 'sizes_mm' => sizes, 'pn' => pn },
                                  data_changed_at: Time.current)
    supplier
  end
end
