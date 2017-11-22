require 'middleman'
require File.join(File.dirname(__FILE__), 'version')
require 'rack/utils'
require 'padrino-helpers'


class Breadcrumbs < Middleman::Extension
  include BreadcrumbsVersion
  include Padrino::Helpers

  option :separator, ' > ', 'Default separator between breadcrumb levels'
  option :wrapper, nil, 'Name of tag (as symbol) in which to wrap each breadcrumb level, or nil for no wrapping'

  expose_to_template :breadcrumbs

  def initialize(app, options_hash = {}, &block)
    super
    @separator = options.separator
    @wrapper = options.wrapper
  end

  def breadcrumbs(page, separator: @separator, wrapper: @wrapper)
    hierarchy = find_parents(page)
    hierarchy.collect do |hpage|
      if hpage.is_a?(String)
        wrap hpage, wrapper: wrapper
      else
        wrap link_to(title_helper(hpage), hpage.url), wrapper: wrapper
      end
    end.join(h separator)
  end

  private

  def wrap(content, wrapper: nil)
    wrapper ? content_tag(wrapper) { content } : content
  end

  # finds all parents for the provided page, based on path
  # parents that do not exist (like folders) are returned as strings
  # returns an Array of resources/strings
  def find_parents(this_page)
    trail = [this_page]
    if this_page.path.include?("/")
      path = this_page.path
      while path.include?("/")
        path, _, current = path.rpartition("/")
        page_id =  path
        page_id += "/index"
        trail << (find_resource(page_id) || path.rpartition("/").last) unless current == "index.html"
      end

    end
    trail << find_resource("index") unless this_page == find_resource("index")
    trail.reverse
  end

  # looks up a resource via its page_id
  def find_resource(page_id)
    app.sitemap.find_resource_by_page_id(page_id)
  end

  # Utility helper for getting the page title for display in the navtree.
  # Based on this: http://forum.middlemanapp.com/t/using-heading-from-page-as-title/44/3
  # 1) Use the title from frontmatter metadata, or
  # 2) peek into the page to find the H1, or
  # 3) fallback to a filename-based-title
  def title_helper(page = current_page)
    if page.directory_index? && page.path != "index.html"# dont be clever with indexes
      filename = page.url.split("/").last.gsub('%20', ' ').titleize
      return filename.chomp(File.extname(filename))
    elsif page.try(:data).try(:breadcrumb_title)
      return page.data.breadcrumb_title # Frontmatter breadcrum title
    elsif page.try(:data).try(:title)
      return page.data.title # Frontmatter title
    elsif match = page.render({:layout => false, :no_images => true}).match(/<h.+>(.*?)<\/h1>/)
      return match[1] # H1 title
    else
      filename = page.url.split(/\//).last.gsub('%20', ' ').titleize
      return filename.chomp(File.extname(filename))
    end
  end
end
