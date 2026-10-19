# One enquiry form (/enquiry/<key>), defined in config/enquiry_topics.yml.
# These replaced the Google Forms the site used to link to.
class EnquiryTopic
  Field = Data.define(:key, :label, :type, :required, :options, :hint) do
    def checkboxes? = type == 'checkboxes'
    def choice? = type == 'choice'
  end

  CONTACT_FIELDS = %w[company designation website].freeze

  attr_reader :key, :title, :intro, :submit, :fields

  def self.all
    @all = nil if Rails.env.development?
    @all ||= YAML.load_file(Rails.root.join('config/enquiry_topics.yml')).to_h { |attrs| [attrs['key'], new(attrs)] }
  end

  def self.find(key) = all[key.to_s]

  def initialize(attrs)
    @key, @title, @intro, @submit = attrs.values_at('key', 'title', 'intro', 'submit')
    # "company!" asks for the company and requires it
    @contact = Array(attrs['contact']).to_h { |name| [name.delete_suffix('!'), name.end_with?('!')] }
    @fields = attrs.fetch('fields').map do |field|
      Field.new(key: field['key'], label: field['label'], type: field['type'], required: field['required'] == true,
                options: Array(field['options']), hint: field['hint'])
    end
  end

  def asks?(contact_field) = @contact.key?(contact_field)
  def requires?(contact_field) = @contact[contact_field] == true

  # For params.permit: checkbox answers are lists
  def permitted_answers = fields.map { |field| field.checkboxes? ? { field.key => [] } : field.key }

  # The submitted answers as { question => answer }, keeping only offered
  # options; designation and website are kept with them
  def answers_from(params)
    given = params[:answers] || {}
    answers = fields.to_h do |field|
      value = given[field.key]
      value = if field.checkboxes? then Array(value).map(&:to_s) & field.options
              elsif field.choice? then field.options.include?(value.to_s) ? value.to_s : nil
              else value.to_s.strip.truncate(2000).presence
              end
      [field.label, value.presence]
    end
    answers['Designation'] = params[:designation].to_s.strip.truncate(120).presence if asks?('designation')
    answers['Website'] = params[:website].to_s.strip.truncate(200).presence if asks?('website')
    answers.compact
  end

  # Required questions left unanswered, as error messages
  def missing(answers, company:)
    missing = fields.select { |field| field.required && answers[field.label].blank? }.map(&:label)
    missing << 'Designation' if requires?('designation') && answers['Designation'].blank?
    missing << 'Company name' if requires?('company') && company.blank?
    missing.map { |label| "#{label.delete_suffix('?')} is required" }
  end
end
