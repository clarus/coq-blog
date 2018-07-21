all: clean
	mkdir blog
	ln -rs static blog/static
	ruby coq_blog.rb

watch:
	while inotifywait posts/*; do make; done

clean:
	rm -Rf blog/

serve:
	@echo Starting on http://localhost:8000/
	ruby -run -e httpd blog/ -p 8000
