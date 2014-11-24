# Coq Blog
A blog about Coq. Hosted on [coq-blog.clarus.me](http://coq-blog.clarus.me/).

## Use
Install the dependencies (you first need Ruby):

    gem install redcarpet
    curl -L https://github.com/clarus/coq-red-css/releases/download/1.0.0/style.min.css >static/style.min.css

Compile:

    make

Compile each time a post is updated:

    while inotifywait posts/*; do make; done

Preview the results on [localhost:8000](http://localhost:8000/):

    make serve
