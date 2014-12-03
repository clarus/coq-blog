You should always write your code to make it compatible with at least two consecutive Coq versions, if you wish to have larger people adoption.

The pace of Coq releases is surprising slow for a project with that many users (mainly due to some organization problems, but I will not debate about it). However, the releases happen and usually introduce a lot of incompatibilities. At this point, users depending on your libraries may be forced to migrate because of other dependencies, or forced not to migrate. Playing nice with them means allowing them to have the choice.

More important, in practice a lot of people prefer to use the development version of Coq (due to the slow release cycle). So your code should at least support the latest stable release and the current development version.

## Check your package
[OPAM](http://opam.ocamlpro.com/) is the best way to test your code with different versions of Coq. You can read this [introduction](http://coq-blog.clarus.me/use-opam-for-coq.html) to learn more about how to use OPAM for Coq.

Let us say we want to test our project `foo` with Coq versions `8.4.5` and `dev`. We create two installs of Coq in `foo/opam.8.4.5` and `foo/opam.dev`. For the stable version:

    cd foo/
    mkdir opam.8.4.5 # we create the empty directory to prevent a bug of OPAM
    opam init --root=opam.8.4.5
    eval `opam config --root=opam.8.4.5 env`
    opam install --jobs=4 coq.8.4.5

In an other terminal, for the unstable Coq:

    mkdir opam.dev
    opam init --root=opam.dev
    eval `opam config --root=opam.dev env`
    opam repo add coqs https://github.com/coq/repo-coqs.git
    opam install --jobs=4 coq.dev

You have now a different version of Coq in each terminal, and can test your code for these versions. People with older computers, who may be afraid of having many Coq installations for each project, remember you can always use cache mechanisms like the one provided by [Docker](https://www.docker.com/) to save disk space.

* bench

## Write simple code

## Preprocessing done right
