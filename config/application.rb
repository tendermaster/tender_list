require_relative "boot"

require "rails/all"

# https://github.com/radar/distance_of_time_in_words
require 'dotiw'
include ActionView::Helpers::DateHelper
include ActionView::Helpers::TextHelper
include ActionView::Helpers::NumberHelper

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module TenderList
  class Application < Rails::Application

    config.assets.paths << Rails.root.join('node_modules')

    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # https://stackoverflow.com/questions/6372626/using-active-record-generators-after-mongoid-installation
    config.generators do |g|
      g.orm :active_record
    end

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
    config.hosts << "ubuntu-vm.test"
  end
end
