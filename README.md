# Coq Blog
A blog about Coq. Hosted on [coq-blog.clarus.me](http://coq-blog.clarus.me/).

## Use or fork to make your own blog
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

## WIP posts
WIP posts are posts with no links from the index so that you can share them for review first. In order to mark a post as Work In Progress, add `wip` in its title. It will not appear in the list of posts, but still be generated. To get the list of WIP posts, go to `http://my-url/wip.html`.

## License
Published under MIT License. This holds both for the posts and the blog engine.
