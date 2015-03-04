We will explain how to write scripts in [Coq](https://coq.inria.fr/) with the example of [repos2web](https://github.com/clarus/repos2web), a website generator. This generator parses an [OPAM](http://opam.ocaml.org/) repository with Coq packages (for example, the [repo-stable](https://github.com/coq/repo-stable)) and generates an HTML page (see the [repo-stable page](http://clarus.github.io/repos2web/)).

## Get started
Install the [coq:io:system](https://github.com/clarus/io-system) package with [OPAM](http://coq-blog.clarus.me/use-opam-for-coq.html) to enable the system effects:

    opam repo add coq-stable https://github.com/coq/repo-stable.git
    opam install coq:io:system

Create an empty Coq project by adding the following files in a fresh directory:

* `configure.sh`:

        #!/bin/sh

        coq_makefile -f Make -o Makefile

* `Make`:

        -R src Repos2Web

        src/Main.v

* `src/Main.v`:

        Require Import Coq.Lists.List.
        Require Import Io.All.
        Require Import Io.System.All.
        Require Import ListString.All.

        Import ListNotations.
        Import C.Notations.

        (** The main function. *)
        Definition main (argv : list LString.t) : C.t System.effects unit :=
          System.log (LString.s "test").

        (** The extracted program. *)
        Definition repos2web := Extraction.run main.
        Extraction "extraction/repos2web" repos2web.

* `extraction/Makefile`:

        build:
        	ocamlbuild repos2web.native -use-ocamlfind -package io-system

        clean:
        	ocamlbuild -clean

Compile your Coq code to [OCaml](http://ocaml.org/):

    ./configure.sh
    make

Compile and run the generated OCaml:

    cd extraction/
    make
    ./repos2web.native

This should print you the message `test`!

## Parse the OPAM repository
To write our script we need to understand the basics of how OPAM for Coq repositories are organized (for example the [repo-stable](https://github.com/coq/repo-stable)). All the packages are in the [packages](https://github.com/coq/repo-stable/tree/master/packages) folder. There is one folder per package name, all prefixed by `coq:` because we are in the Coq namespace. In each package folder there is one folder per version of the package, with three files `descr`, `opam` and `url` to describe the package.

We describe a model of an OPAM repository in [src/Model.v](https://github.com/clarus/repos2web/blob/master/src/Model.v). In a first pass, we will generate an element of type `Packages.t`. This is a list of packages described by a name and a list of version. In a second pass, we will generate an element of type `FullPackages.t` adding the description of each version and computing the latest version using the [Debian ordering](http://manpages.ubuntu.com/manpages/quantal/man5/deb-version.5.html).

### First pass
The first pass is described in [src/Main.v](https://github.com/clarus/repos2web/blob/master/src/Main.v) in the `Basic` module. The function `list_coq_files` lists the files/folders in `folder` starting with the `coq:` prefix:

    Definition list_coq_files (folder : LString.t) : C (option (list Name.t)) :=
      let! folders := System.list_files folder in
      match folders with
      | None =>
        do! log (LString.s "The folder " ++ folder ++ LString.s " cannot be listed.") in
        ret None
      | Some folders => ret (Some (Name.of_strings folders))
      end.

Let us precise the return type `C (option (list Name.t))`. We defined `C` as:

    Definition C := C.t System.effects.

for convenience. This means than `C` is the type of computations doing interactions with the system. We need to use this special type because Coq is a purely functional language, which means that otherwise there cannot be computations doing inputs--outputs.

The type `C` is parametrized by `option (list Name.t)`. The result of `list_coq_files` can be either:

* `None` in case of error,
* some list of names in case of success.

As described in [Tutorial: a Hello World in Coq](http://coq-blog.clarus.me/tutorial-a-hello-world-in-coq.html), we use the `let!` operator to combine computations and `ret` to return a pure value as a result. We interact with the system by calling the following functions:

* `list_files : LString.t -> C (option (list LString.t))`: list the content of a folder
* `log : LString.t -> C unit`: print a message on the terminal

The complete list of functions is available on [system API](http://clarus.github.io/doc/io-system/Io.System.System.html).

### Second pass
