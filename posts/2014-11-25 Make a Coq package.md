We will show you a typical workflow to create and publish a Coq package with [OPAM](http://opam.ocamlpro.com/). This will allow you to share your Coq developments in a simple way and gain visibility.

We assume you already know how to use OPAM to install Coq packages. If not, you can read this [tutorial](http://coq-blog.clarus.me/use-opam-for-coq.html).

## Create a project
Go on [GitHub](https://github.com/) and make a new project, for example `that-super-proof`. Add a `LICENSE` file with your copyright if you want to make your package open-source (without a license a code is proprietary). I usually choose the [MIT](http://opensource.org/licenses/MIT) license, as one of the most permissive and popular:

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

### The case of OCaml plugins
If your project is a Coq plugin (containing [OCaml](https://ocaml.org/) files), you can get inspiration from the [Constructors](https://github.com/mattam82/Constructors) project of [Matthieu Sozeau](http://www.pps.univ-paris-diderot.fr/~sozeau/). This is an example of a simple OCaml plugin, including the branches `v8.4` and `v8.5` for compatibility with the different versions of Coq.

## Compile
We will use `coq_makefile` to generate a Makefile. Create a file `Make`:

    -R . ThatSuperProof

    All.v

and an executable file `configure.sh`:

    #!/bin/sh

    coq_makefile -f Make -o Makefile

To compile your project, run:

    ./configure.sh
    make

`coq_makefile` is clever and also generates an `install` rule, among over things.

## Publish
To publish a new version you need to make a release. In the GitHub page of your project, go to the *releases* section and add a new release named `1.0.0`. People tend to use the [SemVer](http://semver.org/) convention for the version names, as `MAJOR.MINOR.PATCH`:

* `MAJOR`: major changes
* `MINOR`: minor changes
* `PATCH`: bug fixes

We do a pull-request to add our new package (see [pull-requests on GitHub](https://help.github.com/articles/using-pull-requests/) if you need help). Fork the [OPAM Coq repository](https://github.com/coq/opam-coq-archive) and add a folder `coq:that-super-proof/coq:that-super-proof.dev` in `released/packages/`. All package names must be in small caps and start by `coq:` namespace.

A package is described by three files:

* `descr`

        An arithmetic library.

* `opam`

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
          "coq" {>= "8.4.5" & < "8.5~"}
        ]

  The `< "8.5~"` is there to say that the Coq version must be lesser than `8.5.0`, `8.5.1`, ... as well as `8.5~beta1`, `8.5~beta2`, ...

* `url`

        http: "https://github.com/myself/that-super-proof/archive/1.0.0.tar.gz"
        checksum: "da1da74c8f6c560b153ab8dc558cf29e"

The MD5 checksum is mandatory, and can be obtained with:

    curl -L https://github.com/myself/that-super-proof/archive/1.0.0.tar.gz |md5sum

You can test your own fork of the OPAM Coq repository using `opam repo add` on the folder `released` of your fork. Then, issue a pull-request with your new package.

## Use the bench
There is a bench system available on [coq-bench.github.io](http://coq-bench.github.io/). We test all the packages for each version of Coq. We host this service to help you to check that your packages compile for each platform, even development ones. Compatibility across Coq versions is not necessary but allows you to reach more users. You can specify the Coq versions you depend upon in the `depends` field of your `opam` files.
