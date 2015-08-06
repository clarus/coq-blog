require 'erb'
require 'redcarpet'
include ERB::Util

class Blog
  attr_reader :title, :url, :disqus, :posts

  def initialize(title, url, disqus)
    @title, @url, @disqus = title, url, disqus
    @posts = Dir.glob("posts/*.md").map {|file_name| Post.new(file_name)}
      .sort_by {|post| post.date}.reverse
  end
end

class MarkdownRender < Redcarpet::Render::HTML
  include Redcarpet::Render::SmartyPants

  def image(link, title, alt_text)
    "<img src=\"#{h(link)}\" alt=\"#{h(alt_text)}\" class=\"img-responsive center-block\" /><div class=\"text-center\"><mark>#{h(title)}</mark></div>"
  end
end

class Post
  attr_reader :name, :date, :html, :url

  def initialize(file_name)
    if /\A(\d+)-(\d+)-(\d+)\s*(.*)\z/ === File.basename(file_name, ".md") then
      @date = Time.local($1, $2, $3)
      @name = $4
    else
      raise "The name #{file_name.inspect} should have the form \"yyyy-mm-dd title.md\"."
    end
    markdown = File.read(file_name, encoding: "UTF-8")
    @html = Redcarpet::Markdown.new(MarkdownRender).render(markdown)
    @url = "#{@name.gsub(/[^a-zA-Z0-9]+/, "-").downcase}.html"
  end

  def date_string
    @date.strftime("%B %e, %Y")
  end
end

def render_erb(file_name, binding)
  ERB.new(File.read(file_name, encoding: "UTF-8")).result(binding)
end

def header(blog, title)
  render_erb("templates/header.html.erb", binding)
end

def footer
  render_erb("templates/footer.html.erb", binding)
end

blog = Blog.new("Coq blog - Guillaume Claret", "http://coq-blog.clarus.me/", "coqblog")

for page in ["index.html", "rss.xml"] do
  File.open("blog/#{page}", "w") do |f|
    f << render_erb("#{page}.erb", binding)
  end
end

for post in blog.posts do
  File.open("blog/#{post.url}", "w") do |f|
    f << render_erb("templates/post.html.erb", binding)
  end
end
