namespace :products do
  desc 'Add products from db/data/products.yml that are not in the database yet (edits made in /admin are kept)'
  task import: :environment do
    YAML.load_file(Rails.root.join('db/data/products.yml')).each_with_index do |attrs, index|
      product = Product.find_or_initialize_by(slug: attrs.fetch('slug'))
      next puts("kept    #{product.slug}") if product.persisted?

      product.update!(attrs.slice('name', 'category', 'summary', 'body').merge(position: (index + 1) * 10))
      puts "added   #{product.slug}"
    end
  end
end
