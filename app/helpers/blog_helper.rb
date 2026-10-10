# frozen_string_literal: true

module BlogHelper
  # Post HTML comes from Commonmarker with raw HTML disabled, so it's safe to
  # mark html_safe; shortcode tokens are then swapped for rendered partials.
  def render_blog_body(post)
    html = post.html_with_placeholders.gsub(%r{<p>(#{BlogShortcodes::TOKEN_PATTERN})</p>}) do
      index = Regexp.last_match(1)[/\d+/].to_i
      shortcode = post.shortcodes[index]
      shortcode ? render_blog_shortcode(shortcode) : ''
    end
    html.html_safe # rubocop:disable Rails/OutputSafety
  end

  def blog_tenders(query, limit)
    return [] if query.blank?

    _pagy, records = TenderSearch.weighted_search(query, 1, per_page: limit.to_i.clamp(1, 10))
    Array(records)
  rescue StandardError => e
    Rails.logger.warn("blog tenders shortcode failed for #{query.inspect}: #{e.message}")
    []
  end

  # Only http(s) or site-relative links are allowed in button shortcodes.
  def blog_safe_href(href)
    href = href.to_s.strip
    href.start_with?('/', 'https://', 'http://') ? href : nil
  end

  private

  def render_blog_shortcode(shortcode)
    render(partial: "blog/shortcodes/#{shortcode.name}", locals: shortcode.attrs.symbolize_keys).to_str
  rescue StandardError => e
    Rails.logger.warn("blog shortcode #{shortcode.name} failed: #{e.message}")
    ''
  end
end
