module Marketplace
  # The shape of each page's `data` and `breadcrumbs` in marketplace.pages:
  # part of the contract with products-web, like the views. Declared once
  # here; bin/rails marketplace:dump_page_data_schema writes
  # db/marketplace/page-data.schema.json, from which products-web generates
  # Zod, and a test checks every page Catalog makes against it.
  #
  # Types: 'string', 'integer', 'number', a trailing '?' allows null,
  # [type] is a list, { key => type } an object with exactly those keys.
  module PageData
    FILE = Rails.root.join('db/marketplace/page-data.schema.json')

    TERM = { 'term' => 'string' }.freeze

    SHAPES = {
      'category' => TERM.merge(
        'makers' => 'integer',
        'states' => [{ 'name' => 'string', 'makers' => 'integer', 'path' => 'string?' }],
        'grades' => [{ 'slug' => 'string', 'label' => 'string?', 'makers' => 'integer' }],
        'sizes' => [{ 'mm' => 'number', 'makers' => 'integer' }],
        'standards' => ['string'],
        'faqs' => [['string']],
        'guide_html' => 'string'
      ),
      'price' => TERM,
      'size-chart' => TERM,
      'size' => TERM.merge('size_mm' => 'number', 'label' => 'string', 'makers' => 'integer'),
      'grade' => TERM.merge('grade' => 'string', 'label' => 'string', 'makers' => 'integer'),
      'brand' => TERM.merge('brand' => 'string', 'licences' => 'integer'),
      'state' => TERM.merge('state' => 'string', 'makers' => 'integer'),
      'city' => TERM.merge('city' => 'string', 'districts' => ['string'], 'makers' => 'integer'),
      'supplier' => { 'categories' => [{ 'slug' => 'string', 'name' => 'string' }], 'place' => 'string' }
    }.freeze

    BREADCRUMBS = [{ 'label' => 'string', 'path' => 'string?' }].freeze

    def self.json_schema
      {
        '$schema' => 'https://json-schema.org/draft/2020-12/schema',
        'title' => 'MarketplacePageData',
        'description' => "Each marketplace page's data by template, and breadcrumbs. Generated from " \
                         'Marketplace::PageData by bin/rails marketplace:dump_page_data_schema; do not edit.',
        'type' => 'object',
        'properties' => SHAPES.transform_values { schema_for(_1) }.merge('breadcrumbs' => schema_for(BREADCRUMBS)),
        'required' => [*SHAPES.keys, 'breadcrumbs'],
        'additionalProperties' => false
      }
    end

    def self.dump! = FILE.write("#{JSON.pretty_generate(json_schema)}\n")

    # Problems with a value against a shape: [] when it fits
    def self.errors(value, shape = nil, path = 'data', template: nil)
      shape ||= SHAPES.fetch(template)
      case shape
      when Hash
        return ["#{path}: not an object"] unless value.is_a?(Hash)

        extra = value.keys - shape.keys
        missing = shape.keys - value.keys
        [*extra.map { "#{path}.#{_1}: not in the shape" }, *missing.map { "#{path}.#{_1}: missing" },
         *shape.flat_map { |key, type| value.key?(key) ? errors(value[key], type, "#{path}.#{key}") : [] }]
      when Array
        return ["#{path}: not a list"] unless value.is_a?(Array)

        value.each_with_index.flat_map { |item, i| errors(item, shape.first, "#{path}[#{i}]") }
      else
        nullable = shape.end_with?('?')
        return [] if value.nil? && nullable

        ok = { 'string' => String, 'integer' => Integer, 'number' => Numeric }.fetch(shape.delete_suffix('?'))
        value.is_a?(ok) ? [] : ["#{path}: expected #{shape}, got #{value.inspect.first(40)}"]
      end
    end

    def self.schema_for(shape)
      case shape
      when Hash
        { 'type' => 'object', 'properties' => shape.transform_values { schema_for(_1) },
          'required' => shape.keys, 'additionalProperties' => false }
      when Array then { 'type' => 'array', 'items' => schema_for(shape.first) }
      else
        type = shape.delete_suffix('?')
        shape.end_with?('?') ? { 'type' => [type, 'null'] } : { 'type' => type }
      end
    end
  end
end
