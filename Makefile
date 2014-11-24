all: clean
	mkdir blog
	ln -rs static blog/static
	ruby coq_blog.rb

clean:
	rm -Rf blog/

serve:
	ruby -run -e httpd blog/ -p 8000
