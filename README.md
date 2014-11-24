# Coq Blog
[coq-blog.clarus.me](http://coq-blog.clarus.me/)

Install dependencies:

    gem install redcarpet
    curl -L https://github.com/clarus/coq-red-css/releases/download/1.0.0/style.min.css >static/style.min.css

Compile:

    make

Compile each time a post is updated:

    while inotifywait posts/*; do make; done

Preview the results on [localhost:8000](http://localhost:8000/):

    make serve
