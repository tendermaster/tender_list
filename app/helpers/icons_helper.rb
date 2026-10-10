# frozen_string_literal: true

module IconsHelper
  # Inline Lucide icons, vendored from lucide-static (pinned, see the SVG
  # header) into app/assets/images/icons/lucide. Replaces loading the whole
  # library from unpkg@latest at runtime. Add an icon by copying its SVG there.
  LUCIDE_DIR = Rails.root.join('app', 'assets', 'images', 'icons', 'lucide')
  LUCIDE_CACHE = Concurrent::Map.new

  def lucide_icon(name, css_class: nil)
    svg = LUCIDE_CACHE.compute_if_absent(name.to_s) { load_lucide_svg(name.to_s) }
    return ''.html_safe if svg.nil?

    svg.sub('class="lucide ', %(class="#{ERB::Util.html_escape(css_class)} lucide )).html_safe # rubocop:disable Rails/OutputSafety
  end

  private

  def load_lucide_svg(name)
    return nil unless name.match?(/\A[a-z0-9-]+\z/)

    path = LUCIDE_DIR.join("#{name}.svg")
    return nil unless path.file?

    path.read
        .sub(/<!--.*?-->/m, '')
        .sub('<svg', '<svg aria-hidden="true" focusable="false"')
        .gsub(/\s+/, ' ')
        .gsub('> <', '><')
        .strip
  end
end
