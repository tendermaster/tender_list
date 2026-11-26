module Marketplace
  # The JSON Schema of a quote request's `lead` fields (POST /api/v1/leads),
  # built from Lead's own validations, so products-web's form (Zod, generated
  # from db/marketplace/lead-request.schema.json) checks what Rails checks.
  # Rules that can't be expressed here (a valid phone, a throwaway email)
  # come back as 422 errors on the field.
  module LeadSchema
    FILE = Rails.root.join('db/marketplace/lead-request.schema.json')

    def self.build
      properties = Api::V1::LeadsController::LEAD_FIELDS.to_h { |field| [field.to_s, property(field)] }
      {
        '$schema' => 'https://json-schema.org/draft/2020-12/schema',
        'title' => 'LeadRequest',
        'description' => 'The lead fields of a quote request (POST /api/v1/leads). Generated from Lead ' \
                         'validations by bin/rails marketplace:dump_lead_schema; do not edit.',
        'type' => 'object',
        'properties' => properties,
        'required' => Api::V1::LeadsController::LEAD_FIELDS.map(&:to_s).select { required?(_1) },
        'additionalProperties' => false
      }
    end

    def self.dump! = FILE.write("#{JSON.pretty_generate(build)}\n")

    def self.property(field)
      schema = { 'type' => 'string' }
      validators(field).each do |validator|
        case validator
        when ActiveModel::Validations::LengthValidator
          schema['maxLength'] = validator.options[:maximum] if validator.options[:maximum]
        when ActiveModel::Validations::InclusionValidator
          schema['enum'] = validator.options[:in] if validator.options[:in].is_a?(Array)
        when ActiveModel::Validations::FormatValidator
          schema['format'] = 'email' if validator.options[:with] == URI::MailTo::EMAIL_REGEXP
        end
      end
      schema['minLength'] = 1 if required?(field)
      schema
    end

    def self.required?(field)
      validators(field).any? { _1.is_a?(ActiveRecord::Validations::PresenceValidator) }
    end

    # Validators that apply to a quote request: unconditional ones, and those
    # conditioned on the kind (if: :quote?, unless: :enquiry?)
    def self.validators(field)
      quote = Lead.new(kind: :quote)
      Lead.validators_on(field).select do |validator|
        ifs = Array(validator.options[:if])
        unlesses = Array(validator.options[:unless])
        next false if (ifs + unlesses).any? { !_1.is_a?(Symbol) }

        ifs.all? { quote.send(_1) } && unlesses.none? { quote.send(_1) }
      end
    end
  end
end
