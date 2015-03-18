Coq now has its package manager: [OPAM](http://opam.ocamlpro.com/). This is already the package manager of [OCaml](https://ocaml.org/) so it was the natural choice for us, since Coq and its plugins are already coded in OCaml.

## Install OPAM
Install OPAM by your preferred method. It is recommended to use at least the version (`1.2.1` as of March 18, 2015), which can be installed from the sources:

    curl -L https://github.com/ocaml/opam/archive/1.2.1.tar.gz |tar -xz
    cd opam-1.2.1
    ./configure
    make lib-ext
    make
    sudo make install

By default the OPAM packages are installed in `~/.opam`. You can also have many installation folders. A good practice is to have one installation folder per project. Then your are safe if you need different versions of Coq or packages for each project. To configure OPAM for the current folder:

    mkdir opam
    opam init --root=opam # answer no to the question
    eval `opam config env --root=opam` # set the env variables for this shell session

**Remark:** Some people from OCaml are more used to the `switch` mechanism to handle many OPAM installations.

## Add the repositories
Now you can add the Coq [stable repository](https://github.com/coq/repo-stable):

    opam repo add coq-stable https://github.com/coq/repo-stable.git

The stable repository contains only released packages. There is also the [unstable repository](https://github.com/coq/repo-unstable) for development versions. You should use it at your own risks:

    opam repo add coq-unstable https://github.com/coq/repo-unstable.git

The [coqs repository](https://github.com/coq/repo-coqs) contains development versions of Coq:

    opam repo add coqs https://github.com/coq/repo-coqs.git

## Install a package
The Coq packages are in the namespace `coq:`. To list all of them:

    opam search coq:

To install a package:

    opam install coq:ssreflect

If the package is slow to install (for instance, Coq itself), you can always use the `-j` option:

    opam install -j6 coq
