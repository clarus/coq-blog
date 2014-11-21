all: clean
	mkdir blog
	ln -rs static blog/static
	ruby kalach_blog.rb $(TITLE) $(DISQUS)

clean:
	rm -Rf blog/

serve:
	ruby -run -e httpd blog/ -p 8000
