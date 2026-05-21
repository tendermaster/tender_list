# frozen_string_literal: true

class ApiSearchCors
  SEARCH_PATH = %r{\A/api/v1/search/?\z}
  HEADERS = {
    'Access-Control-Allow-Origin' => '*',
    'Access-Control-Allow-Methods' => 'GET, OPTIONS',
    'Access-Control-Allow-Headers' => 'Origin, Content-Type, Accept, Authorization',
    'Access-Control-Max-Age' => '86400'
  }.freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    return @app.call(env) unless SEARCH_PATH.match?(env['PATH_INFO'].to_s)

    return [204, HEADERS.merge('Content-Length' => '0'), []] if env['REQUEST_METHOD'] == 'OPTIONS'

    status, headers, response = @app.call(env)
    HEADERS.each { |key, value| headers[key] = value }
    [status, headers, response]
  end
end
