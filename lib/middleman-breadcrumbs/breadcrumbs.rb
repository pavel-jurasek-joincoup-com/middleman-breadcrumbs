require 'middleman'
require File.join(File.dirname(__FILE__), 'version')
require 'rack/utils'
require 'padrino-helpers'
require 'pry'

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
    #binding.pry
    hierarchy = [page]
    #hierarchy.unshift find_parent(hierarchy.first) while hierarchy.first.parent

    hierarchy = find_all_parents(page)
    binding.pry if page.page_id == "devices/index"
    hierarchy.collect do |page|
      if page.is_a?(String)
        wrap page, wrapper: wrapper
      else
        wrap link_to(title_helper(page), "/#{page.path}"), wrapper: wrapper
      end
    end.join(h separator)
  end

  private

  def wrap(content, wrapper: nil)
    wrapper ? content_tag(wrapper) { content } : content
  end

  def find_the_parent(page)
    return page.parent if page.try(:parent)
    path = page.try(:path) || page
    parents = path.split("/")
    if parents.size > 1
      parents.pop if parents.last.end_with?(".html")
      index_id = parents.join("/") + "/index"
    else
      index_id = path.split(".").first
    end
    find_resource(index_id) || parents.last
  end

  def find_all_parents(this_page)
    parents = this_page.path.split("/")[0..-2]
    result = []
    parents.reverse_each do |parent|
      found  = find_the_parent(parents.join("/"))
      result << found
      parents.pop
      parents.pop if parent.start_with?("index") && parents.size > 1
    end
    if this_page.page_id == "index"
      result << this_page
    else
      result << find_resource("index")
      result.reverse!
      result << this_page
    end
    result
  end

  def find_resource(page_id)
    app.sitemap.find_resource_by_page_id(page_id)
  end

  # Utility helper for getting the page title for display in the navtree.
  # Based on this: http://forum.middlemanapp.com/t/using-heading-from-page-as-title/44/3
  # 1) Use the title from frontmatter metadata, or
  # 2) peek into the page to find the H1, or
  # 3) Use the home_title option (if this is the home page--defaults to "Home"), or
  # 4) fallback to a filename-based-title
  def title_helper(page = current_page)
    if page.data.title
      return page.data.title # Frontmatter title
    elsif match = page.render({:layout => false, :no_images => true}).match(/<h.+>(.*?)<\/h1>/)
      return match[1] # H1 title
    else
      filename = page.url.split(/\//).last.gsub('%20', ' ').titleize
      return filename.chomp(File.extname(filename))
    end
  end
end
