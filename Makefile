# Blog's title
TITLE="Title"

# Root url
URL="http://www.example.com/"

# Login on Disqus (you need an account to use the comment system)
DISQUS="disquslogin"

all: clean
	mkdir blog
	ln -rs static blog/static
	ruby kalach_blog.rb $(TITLE) $(URL) $(DISQUS)

clean:
	rm -Rf blog/

serve:
	ruby -run -e httpd blog/ -p 8000
