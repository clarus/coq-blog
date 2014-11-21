require 'erb'
include ERB::Util

class Blog
  attr_reader :title, :disqus, :pages, :posts
  
  def initialize(title, disqus)
    @title, @disqus = title, disqus
    @posts = Dir.glob("posts/*").map {|file_name| Post.new(file_name)}
      .sort_by {|post| post.date}.reverse
    @pages = Dir.glob("pages/*")
  end
end

class Post
  attr_reader :name, :date, :content, :url
  
  def initialize(file_name)
    if /\A(\d+)-(\d+)-(\d+)\s*(.*)\z/ === File.basename(file_name, ".html") then
      @date = Time.local($1, $2, $3)
      @name = $4
    else
      raise "The name #{file_name.inspect} should have the form \"yyyy-mm-dd title.html\"."
    end
    @content = File.read(file_name, encoding: "UTF-8")
    @url = "#{@name.gsub(/[^a-zA-Z0-9]/, "-")}.html"
  end

  def date_string
    @date.strftime("%B %e, %Y")
  end
end

class ErbFile
  def initialize(file_name)
    @erb = ERB.new(File.read(file_name, encoding: "UTF-8"))
  end
  
  def result(binding)
    @erb.result(binding).gsub(/^\s*$\n/, "")
  end
end

module Helpers
  def header(blog, title, active_link)
    ErbFile.new("templates/header.html.erb").result(binding)
  end
  
  def footer
    ErbFile.new("templates/footer.html.erb").result(binding)
  end
end

class View
  include Helpers
  attr_reader :url, :html
end

class PageView < View
  def initialize(blog, file_name)
    @url = File.basename(file_name, ".erb")
    @html = ErbFile.new(file_name).result(binding)
  end
end

class PostView < View
  def initialize(blog, post)
    @url = post.url
    @html = ErbFile.new("templates/post.html.erb").result(binding)
  end
end

class Renderer
  def initialize(blog)
    @blog = blog
  end
  
  def render
    page_views = @blog.pages.map {|file_name| PageView.new(@blog, file_name)}
    post_views = @blog.posts.map {|post| PostView.new(@blog, post)}
    (page_views + post_views).each do |view|
      File.open("blog/#{view.url}", "w") {|f| f << view.html}
    end
  end
end

Renderer.new(Blog.new(*ARGV)).render
