all: clean
	mkdir blog
	ln -rs static blog/static
	ruby coq_blog.rb

watch:
	while inotifywait posts/* next_posts/*; do make; done

clean:
	rm -Rf blog/

serve:
	ruby -run -e httpd blog/ -p 8000
