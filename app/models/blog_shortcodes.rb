# frozen_string_literal: true

# Shortcodes are the blog's equivalent of MDX components: a line such as
#
#   {{ tenders query="mild steel" limit=5 }}
#
# on its own in a post renders app/views/blog/shortcodes/_tenders.html.erb.
# Only names in ALLOWED render; anything else is dropped, so a post file can't
# reach arbitrary partials.
module BlogShortcodes
  ALLOWED = {
    'cta' => [],
    'button' => %w[href label],
    'tenders' => %w[query limit]
  }.freeze

  LINE_PATTERN = /^[ \t]*\{\{\s*([a-z_]+)((?:\s+[a-z_]+=(?:"[^"]*"|\S+))*)\s*\}\}[ \t]*$/
  ATTR_PATTERN = /([a-z_]+)=(?:"([^"]*)"|(\S+))/
  TOKEN_PREFIX = 'BLOGSHORTCODE'
  TOKEN_PATTERN = /#{TOKEN_PREFIX}\d+X/

  Shortcode = Struct.new(:name, :attrs, keyword_init: true)
  Result = Struct.new(:markdown, :shortcodes, keyword_init: true)

  module_function

  # Replaces each shortcode line with a token paragraph ("BLOGSHORTCODE0X") that
  # survives Markdown rendering as <p>BLOGSHORTCODE0X</p>.
  def extract(markdown)
    shortcodes = []
    replaced = markdown.gsub(LINE_PATTERN) do
      name = Regexp.last_match(1)
      allowed = ALLOWED[name]
      next '' unless allowed

      attrs = Regexp.last_match(2).scan(ATTR_PATTERN).to_h { |key, quoted, bare| [key, quoted || bare] }.slice(*allowed)
      shortcodes << Shortcode.new(name: name, attrs: attrs)
      "\n#{TOKEN_PREFIX}#{shortcodes.size - 1}X\n"
    end
    Result.new(markdown: replaced, shortcodes: shortcodes)
  end
end
