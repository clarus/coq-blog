# Blog's title
TITLE="Title"

# Login on Disqus (you need an account to use the comment system)
DISQUS="disquslogin"

all: clean
	mkdir blog
	ln -rs static blog/static
	ruby kalach_blog.rb $(TITLE) $(DISQUS)

clean:
	rm -Rf blog/

serve:
	ruby -run -e httpd blog/ -p 8000
