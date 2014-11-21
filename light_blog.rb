require 'erb'
include ERB::Util

# Models
class Blog
  attr_reader :title, :url, :disqus, :posts
  
  def initialize(title, url, disqus)
    @title, @url, @disqus = title, url, disqus
    @posts = []
    Dir.foreach("posts") do |file_name|
      if File.extname(file_name) == ".html"
        @posts << Post.new(File.basename(file_name, ".html"))
      end
    end
    @posts.sort! {|a, b| - (a.date <=> b.date)}
  end
end

class Post
  attr_reader :name, :date, :content, :url
  
  def initialize(name)
    file_name = "posts/#{name}.html"
    if /\A(\d+)-(\d+)-(\d+)\s*(.*)\z/ === name
      @date = Time.local($1, $2, $3)
      @name = $4
    else
      @date = Time.at(0)
      @name = name
    end
    @content = File.read(file_name)
    @url = "#{@name}.html"
  end

  def date_string
    @date.strftime("%B %e, %Y")
  end
end

# Views
class Template
  def initialize(file_name)
    @erb = ERB.new(File.read("templates/#{file_name}"))
  end
  
  def result(binding)
    @erb.result(binding).gsub(/^\s*$\n/, "").chomp
  end
end

module Helpers
  def header(blog, title, active_link)
    Template.new("header.rhtml").result(binding)
  end
  
  def footer
    Template.new("footer.rhtml").result(binding)
  end
end

class View
  include Helpers
  attr_reader :url, :html
end

class PageView < View
  def initialize(blog, file_name)
    extension = File.extname(file_name)
    @url = "#{File.basename(file_name, extension)}.#{extension[2..-1]}"
    @html = Template.new(file_name).result(binding)
  end
end

class PostView < View
  def initialize(blog, post)
    @url = post.url
    @html = Template.new("post.rhtml").result(binding)
  end
end

# Controller
class Controller
  def initialize(blog)
    @blog = blog
  end
  
  def make
    pages = ["index.rhtml", "posts.rhtml", "about.rhtml", "rss.rxml"]
    page_views = pages.collect {|file_name| PageView.new(@blog, file_name)}
    post_views = @blog.posts.collect {|post| PostView.new(@blog, post)}
    
    (page_views + post_views).each do |view|
      File.open("blog/#{view.url}", "w") {|f| f << view.html}
    end
  end
end

# Run
Controller.new(Blog.new(*ARGV)).make
