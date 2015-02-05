We will show a typical workflow to create and publish a Coq package on [OPAM](http://opam.ocamlpro.com/). This will allow you to share your Coq developments in a simple way and gain visibility.

OPAM is now the recommended way to distribute Coq packages. Other users just need a:

    opam install coq:that-super-proof

to see what you did and use it.

We assume you already know how to use OPAM to install Coq packages. If not, you can read this [tutorial](http://coq-blog.clarus.me/use-opam-for-coq.html).

## Create a project
Go on [GitHub](https://github.com/) and make a new project, for example `that-super-proof`. To have the best chances to get contributions and remarks, it is a good practice to always chose the tools that most people use. Today, GitHub is the most popular hosting platform for projects, and a pull-request (external contribution) is a matter of a click.

Clone your repository. Add an `LICENSE` file with your copyright to make your package open-source (according to the law, a code is considered proprietary by default). The [MIT](http://opensource.org/licenses/MIT) license is one of the most permissive and popular licenses:

    The MIT License (MIT)

    Copyright (c) <year> <copyright holders>

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
    THE SOFTWARE.

Add a main file `All.v`:

    Theorem two : 1 + 1 = 2.
      now admit.
    Qed.

You can now commit your work.

## Compile
We will use `coq_makefile`. Add a project file `Make`:

    -R . ThatSuperProof

    All.v

and an executable script `configure.sh`:

    #!/bin/sh

    coq_makefile -f Make -o Makefile

Compile with:

    ./configure.sh
    make

Coq Makefile is clever and also generates an `install` rule, among over things.

## Publish a development version
We will first publish a package on the unstable repository. We need to do a pull-request to add a new package (see [pull-requests on GitHub](https://help.github.com/articles/using-pull-requests/)). Fork the [unstable repository](https://github.com/coq/repo-unstable) and add a folder `coq:that-super-proof/coq:that-super-proof.dev` in `packages/`. All packages must be in small caps, in the `coq:` namespace. You can also use your own `coq:name:` namespace for bigger projects.

A package is described by three files:

* `descr`:

        An arithmetic library.

* `opam`:

        opam-version: "1.1"
        maintainer: "me@myself.ninja"
        homepage: "https://github.com/myself/that-super-proof"
        bug-reports: "https://github.com/myself/that-super-proof/issues"
        license: "MIT"
        build: [
          ["./configure.sh"]
          [make "-j%{jobs}%"]
          [make "install"]
        ]
        remove: ["rm" "-R" "%{lib}%/coq/user-contrib/ThatSuperProof"]
        depends: [
          "coq" {>= "8.4.5" & < "8.5"}
        ]

* `url`:

        http: "https://github.com/myself/that-super-proof/archive/master.tar.gz"

You can test your own fork of the unstable repository using `opam repo add` on your fork. Then, issue a pull-request with your new package. It should be accepted quickly since there is no reviewing on the unstable repository (we only check there is no `rm -Rf` or so).

## Make a stable version
To publish a stable version you need to make a release. A release with a version number allows people to express reliable dependencies to your work. In GitHub, go to the *releases* section and add a new release named `1.0.0`. For version names we recommend the [SemVer](http://semver.org/) convention, `MAJOR.MINOR.PATCH` with:

* `MAJOR`: breaking changes
* `MINOR`: non-breaking changes
* `PATCH`: bug fixes

Fork the [stable repository](https://github.com/coq/repo-stable) and add a folder `coq:that-super-proof/coq:that-super-proof.1.0.0` in `packages/`. Add the `descr` and `opam` files as before and a new `url` file:

    http: "https://github.com/myself/that-super-proof/archive/1.0.0.tar.gz"
    checksum: "da1da74c8f6c560b153ab8dc558cf29e"

The MD5 checksum is mandatory, and can be obtained with:

    curl -L https://github.com/myself/that-super-proof/archive/1.0.0.tar.gz |md5sum

Make a pull-request with your package. We will check it is compiling and accept it.

## Use the bench
There is a bench system available on [coq-bench.github.io](http://coq-bench.github.io/). We test all the packages for each version of Coq. We host this service to help you to check that your packages compile for each platform, even development ones. Compatibility across versions is not necessary but allows you to reach more users. And you can always specify the Coq versions you depend upon in the `depends` field of your `opam` files.
