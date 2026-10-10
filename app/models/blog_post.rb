# frozen_string_literal: true

# Blog posts are Markdown files in content/blog/<slug>.md with YAML front matter
# (Astro content-collection compatible: title, description, pubDate, tags, draft).
#
# Files are re-read when their mtime changes, so saving a file publishes it:
# no build step or restart.
class BlogPost
  DIR = Rails.root.join('content', 'blog')
  SLUG_FORMAT = /\A[a-z0-9][a-z0-9-]*\z/
  FRONT_MATTER = /\A---\s*\n(.*?)\n---\s*\n/m
  WORDS_PER_MINUTE = 200

  MARKDOWN_OPTIONS = {
    render: { unsafe: false },          # raw HTML in posts is dropped, not rendered
    extension: { header_ids: '' }       # heading anchors; tables/autolinks are on by default
  }.freeze

  attr_reader :slug, :title, :seo_title, :description, :pub_date, :updated_date, :tags, :body, :mtime

  @cache = {}
  @lock = Mutex.new

  class << self
    def all
      Dir.glob(DIR.join('*.md'))
         .filter_map { |path| load(path) }
         .reject(&:draft?)
         .sort_by { |post| [post.pub_date, post.slug] }
         .reverse
    end

    def find(slug)
      return nil unless slug.to_s.match?(SLUG_FORMAT)

      post = load(DIR.join("#{slug}.md").to_s)
      post unless post.nil? || post.draft?
    end

    private

    # Parsed posts are kept per process and reloaded when the file changes.
    def load(path)
      return nil unless File.file?(path)

      mtime = File.mtime(path)
      @lock.synchronize do
        cached = @cache[path]
        return cached if cached&.mtime == mtime

        @cache[path] = new(path, mtime)
      end
    rescue StandardError => e
      Rails.logger.error("BlogPost: failed to load #{path}: #{e.message}")
      nil
    end
  end

  def initialize(path, mtime)
    raw = File.read(path, encoding: 'UTF-8')
    match = raw.match(FRONT_MATTER) or raise ArgumentError, 'missing front matter'
    meta = YAML.safe_load(match[1], permitted_classes: [Date]) || {}

    @slug = File.basename(path, '.md')
    @mtime = mtime
    @body = raw[match.end(0)..].to_s
    @title = meta.fetch('title')
    @seo_title = meta['seoTitle'].presence
    @description = meta['description'].presence
    @pub_date = to_date(meta.fetch('pubDate'))
    @updated_date = meta['updatedDate'] ? to_date(meta['updatedDate']) : nil
    @tags = Array(meta['tags']).map(&:to_s)
    @draft = meta['draft'] == true
  end

  def draft?
    @draft
  end

  def to_param
    slug
  end

  def last_modified
    updated_date || pub_date
  end

  # Markdown -> HTML, with shortcode lines replaced by placeholder tokens that
  # BlogHelper swaps for rendered partials.
  def html_with_placeholders
    @html_with_placeholders ||= begin
      markdown = BlogShortcodes.extract(body).markdown
      Commonmarker.to_html(markdown, options: MARKDOWN_OPTIONS)
    end
  end

  def shortcodes
    @shortcodes ||= BlogShortcodes.extract(body).shortcodes
  end

  # Used when a post has no description in its front matter.
  def summary(length = 160)
    description || plain_text.truncate(length, separator: ' ')
  end

  def reading_minutes
    [(plain_text.split.size / WORDS_PER_MINUTE.to_f).ceil, 1].max
  end

  private

  def plain_text
    @plain_text ||= ActionController::Base.helpers.strip_tags(
      Commonmarker.to_html(BlogShortcodes.extract(body).markdown.gsub(BlogShortcodes::TOKEN_PATTERN, ''), options: MARKDOWN_OPTIONS)
    ).squish
  end

  def to_date(value)
    value.is_a?(Date) ? value : Date.parse(value.to_s)
  end
end
