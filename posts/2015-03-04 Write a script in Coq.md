We will explain how to write scripts in [Coq](https://coq.inria.fr/) with the example of [repos2web](https://github.com/clarus/repos2web), a website generator. This generator parses an [OPAM](http://opam.ocaml.org/) repository with Coq packages (for example, the [repo-stable](https://github.com/coq/repo-stable)) and generates an HTML page (see the [repo-stable page](http://clarus.github.io/repos2web/)).

## Get started
Install the [coq:io:system](https://github.com/clarus/io-system) package with [OPAM](http://coq-blog.clarus.me/use-opam-for-coq.html) to enable the system effects:

    opam repo add coq-stable https://github.com/coq/repo-stable.git
    opam install coq:io:system

Create an empty Coq project by adding the following files in a fresh directory:

* `configure.sh`, the configure script:

        #!/bin/sh

        coq_makefile -f Make -o Makefile

* `Make`, the `coq_makefile` project file:

        -R src Repos2Web

        src/Main.v

* `src/Main.v`, the main source file:

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

* `extraction/Makefile`, the Makefile for the extracted program:

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

This should print you the message `test` on the terminal!

## Parse the OPAM repository
To write our script we need to understand the basis of how OPAM for Coq repositories are organized (for example the [repo-stable](https://github.com/coq/repo-stable)). All the packages are in the [packages](https://github.com/coq/repo-stable/tree/master/packages) folder. There is one folder per package name, all prefixed by `coq:` because we are in the Coq namespace. In each package folder, there is one folder per version of the package with three files `descr`, `opam` and `url` to describe the package.

    packages/
      coq:list-string/
        coq:list-string.1.0.0/
          descr
          opam
          url
        coq:list-string.2.0.0/
          ...
      ...

We define the data type of an OPAM repository in [src/Model.v](https://github.com/clarus/repos2web/blob/master/src/Model.v). In a first pass, we will generate an element of type `Packages.t`. This is a list of packages described by a name and a list of versions. In a second pass, we will generate an element of type `FullPackages.t`, by adding the description of each version and by computing each latest version using the (complex) [Debian ordering](https://www.debian.org/doc/debian-policy/ch-controlfields.html#s-f-Version).

### First pass
The first pass is described in [src/Main.v](https://github.com/clarus/repos2web/blob/master/src/Main.v) in the `Basic` module. The function `list_coq_files` lists the files/folders which are starting with the `coq:` prefix in a given `folder`:

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

for convenience. This means than `C` is the type of computations doing interactions with the system. We need to use this special type because Coq is a purely functional language: without using the type `C`, functions cannot do inputs--outputs.

The type `C` is parametrized by `option (list Name.t)`, the result type of the function. Thus, the result of `list_coq_files` can be either:

* `None` in case of error,
* some list of names in case of success.

As described in [Tutorial: a Hello World in Coq](http://coq-blog.clarus.me/tutorial-a-hello-world-in-coq.html), we use the `let!` operator to combine computations and the `ret` operator to return a pure value. We interact with the system by calling the following functions:

* `list_files : LString.t -> C (option (list LString.t))`: list the content of a folder
* `log : LString.t -> C unit`: print a message on the terminal

The complete list of system functions is available on [system API](http://clarus.github.io/doc/io-system/Io.System.System.html).

We continue by defining more functions and conclude with:

    Definition get_packages (repository : LString.t) : C (option Packages.t) :=
      let! names := list_coq_files repository in
      match names with
      | None => ret None
      | Some names => get_packages_of_names repository names
      end.

to get the list of packages in a repository folder (or `None` in case of error).

### Second pass
The second pass follows the same structure as the first one. The main trick is the function:

    (** Return the latest version, using Debian `dpkg` for comparison. *)
    Definition max_version (version1 version2 : Version.t) : C (option Version.t) :=
      ...

which uses the `dpkg` command line tool to compare two versions numbers according to the [Debian ordering](https://www.debian.org/doc/debian-policy/ch-controlfields.html#s-f-Version). If you want to test it, the `dpkg` tool should be available on most Linux distribution, even on those which are not based on [Debian](https://www.debian.org/).

## Render the HTML
We define the HTML rendering in [src/View.v](https://github.com/clarus/repos2web/blob/master/src/View.v). The last function is:

    Definition index (packages : FullPackages.t) : LString.t :=
      header ++ title packages ++ table packages ++ footer.

which pretty-prints a list of packages to HTML. This function is pure (no inputs--outputs), because the return type is not `C` of something but `LString.t`. There is nothing special about the pretty-printing, and we generate the page using the [Bootstrap](http://getbootstrap.com/) CSS framework to get a nice rendering.

The final `main` function in [src/Main.v](https://github.com/clarus/repos2web/blob/master/src/Main.v) combines the parsing and the rendering to write the output file in `html/index.html`:

    Definition main (argv : list LString.t) : C unit :=
      match argv with
      | [_; repository] =>
        let repository := repository ++ LString.s "/packages" in
        let! packages := Basic.get_packages repository in
        match packages with
        | None => log (LString.s "The packages cannot be listed.")
        | Some packages =>
          let! full_packages := Full.get_packages repository packages in
          let index_content := View.index full_packages in
          let index_name := LString.s "html/index.html" in
          let! is_success := System.write_file index_name index_content in
          if is_success then
            log (index_name ++ LString.s " generated.")
          else
            log (LString.s "Cannot generate " ++ index_name ++ LString.s ".")
        end
      | _ => log (LString.s "Exactly one argument expected (the repository folder).")
      end.

We use the list of command line arguments `argv` to get the folder in which the OPAM repository is stored. You can add a Coq-ish theme downloading this Bootstrap CSS:

    curl -L https://github.com/clarus/coq-red-css/releases/download/coq-blog.1.0.2/style.min.css >html/style.min.css

## Next time
Next time we will see how to specify this script and prove it correct, using a reasoning by [use cases](http://en.wikipedia.org/wiki/Use_case).
