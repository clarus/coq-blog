[OPAM](http://opam.ocamlpro.com/) a package manager edited by [OCamlPro](http://www.ocamlpro.com/). We will describe how to use it to handle [Coq](https://coq.inria.fr/) packages.

## Install OPAM
Install OPAM by your preferred method. It is recommended to use the latest version (`1.2.2` as of May 7, 2015), which can be installed from the sources:

    curl -L https://github.com/ocaml/opam/archive/1.2.2.tar.gz |tar -xz
    cd opam-1.2.2
    ./configure
    make lib-ext
    make
    sudo make install

By default the OPAM packages are installed in `~/.opam`. You can also have many installation folders if you want many versions of Coq or packages. A practice I recommend is to have one installation folder per project or configuration. To configure OPAM in a fresh folder `opam`:

    mkdir opam
    opam init --root=opam # answer no to the question
    eval `opam config env --root=opam` # run this command for each shell session

**Remark:** Some people also use the `switch` mechanism to handle many OPAM installations.

## Add the repositories
To add the repository for the Coq packages:

    opam repo add coq-released https://coq.inria.fr/opam/released

There is also a repository for the development versions. Use it at your own risks:

    opam repo add coq-extra-dev https://coq.inria.fr/opam/extra-dev

To add the development versions of Coq:

    opam repo add coq-core-dev https://coq.inria.fr/opam/core-dev

**Remark:** There is also a distribution mechanism with [Coq Shell](https://github.com/coq/opam-coq-shell).

## Install a package
The Coq packages are in the namespace `coq:`. To list all of them:

    opam search coq:

To install a package:

    opam install coq:io:hello-world

To specify the version you want to install:

    opam install coq:io:hello-world.1.1.0

If the package is slow to install (for instance, Coq itself), use the `-j` option to speed it up and `-v` to see the progress:

    opam install -j4 -v coq
