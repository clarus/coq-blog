# Coq Blog
A blog about Coq. Hosted on [coq-blog.clarus.me](http://coq-blog.clarus.me/).

## Use
Install the Markdown parser (you first need Ruby):

    gem install redcarpet

Add my coq-ish theme:

    curl -L https://github.com/clarus/coq-red-css/releases/download/coq-blog.1.0.2/style.min.css >static/style.min.css

If you want other themes, add a [Bootstrap](http://getbootstrap.com/) based CSS in `static/style.min.css`. A nice list is available on [Bootswatch](http://bootswatch.com/).

Compile:

    make

Compile each time a post is updated:

    make watch

Preview the results on [localhost:8000](http://localhost:8000/):

    make serve

## License
Published under MIT License. This holds both for the posts and the blog engine. Fell free to clone it.
