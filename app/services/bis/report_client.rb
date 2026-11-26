module Bis
  # Reads BIS ManakOnline's public Conformity Assessment reports (no login,
  # no captcha): the dashboard page carries this month's encrypted date and
  # branch tokens; a report page embeds its rows as JSON in
  # `var jsonvalues = '...'`. One request at a time; the full report (1016)
  # is ~176 MB, so it gets a long timeout and is meant for a one-off run.
  class ReportClient
    BASE = 'https://www.manakonline.in/MANAK/'
    REPORTS = {
      granted: '1015',   # licences granted this month
      all: '1016',       # every licence (very large)
      suspended: '1018',
      cancelled: '1021',
      expired: '1022'
    }.freeze
    USER_AGENT = 'SigmaTenders BIS licence import (+https://sigmatenders.com)'

    class Error < StandardError; end

    def initialize(read_timeout: 300)
      @read_timeout = read_timeout
      @cookies = {}
    end

    # Rows (Hashes) of a report, by name (:granted) or id ('1015')
    def rows(report)
      id = REPORTS.fetch(report) { report.to_s }
      tokens = dashboard_tokens
      path = "BisReportList/#{id}/#{tokens.values_at('fromdate', 'todate', 'branch_id').join('/')}/ALL_BRANCHES"
      self.class.parse_report(get(path).body.force_encoding(Encoding::UTF_8))
    end

    def self.parse_report(html)
      html = html.dup.force_encoding(Encoding::UTF_8) unless html.encoding == Encoding::UTF_8
      raw = html[/var\s+jsonvalues\s*=\s*'(.*?)';\s*$/m, 1]
      raise Error, 'report page has no jsonvalues' if raw.nil?

      JSON.parse(raw.gsub("\\'", "'"))
    rescue JSON::ParserError => e
      raise Error, "report JSON unreadable: #{e.message.first(200)}"
    end

    private

    def dashboard_tokens
      html = get('ConformityAssessment').body
      tokens = %w[fromdate todate branch_id].to_h do |id|
        [id, html[/id="#{id}"[^>]*value="([^"]+)"/, 1]]
      end
      raise Error, "dashboard tokens missing: #{tokens.select { |_, v| v.nil? }.keys.join(', ')}" if tokens.value?(nil)

      tokens
    end

    def get(path)
      uri = URI.join(BASE, path)
      request = Net::HTTP::Get.new(uri)
      request['User-Agent'] = USER_AGENT
      request['Cookie'] = @cookies.map { "#{_1}=#{_2}" }.join('; ') if @cookies.any?
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 20, read_timeout: @read_timeout) do |http|
        http.request(request)
      end
      raise Error, "#{path.split('/').first}: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      Array(response.get_fields('set-cookie')).each do |cookie|
        name, value = cookie.split(';').first.split('=', 2)
        @cookies[name] = value
      end
      response
    end
  end
end
