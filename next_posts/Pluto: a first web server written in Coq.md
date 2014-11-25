[Pluto](https://github.com/coq-concurrency/pluto) is the first web server written in Coq. It is a research project which aims to apply the pure and dependently typed [Coq](https://coq.inria.fr/) language to system programming, with inputs/outputs and fine grained concurrency in mind.

For now it can serve static websites, using event-based I/O and lightweight threads to handle concurrent requests.

## Use
The simplest way to install [Pluto](https://github.com/coq-concurrency/pluto) is to use [OPAM](http://opam.ocamlpro.com/) for Coq. See this [tutorial](http://coq-blog.clarus.me/use-opam-for-coq.html) for more informations. Add the stable and unstable repositories:

    opam repo add coq-stable https://github.com/coq/repo-stable.git
    opam repo add coq-unstable https://github.com/coq/repo-unstable.git

Install Pluto:

    opam install --jobs=4 coq:concurrency:pluto

Run it on some `html/` folder:

    pluto.native 8000 html/

Your website is now available on [localhost:8000](http://localhost:8000/).

## Architecture
Coq is a pure language so it cannot directly express concurrency and I/O. For that we use a Domain Specific Language (DSL) with new primitive constructs to describe impure computations.

### Operators
The `Read` and `Write` commands read or update atomically global references (shared by all the threads). `Ret` lifts a pure Coq expression, `Bind` sequences two computations. The `Send` constructor does an asynchronous call to the OS. It provides a handler with its own private memory (a lightweight thread), called each time an answer is sent to the request. The `Exit` command halts the program and stops all pending handlers.

We decided to use fully asynchronous I/O with lightweight threads for two reasons:

* it is generally considered more efficient than synchronous system-calls plus system-threads (see the evolution from the [Apache](http://www.apache.org/) 1 multi-threaded server to mono-threaded event-driven systems like [Node.js](http://nodejs.org/))
* it corresponds more to what computers intrinsically are: the most primitive communication facilities on microprocessors are the [OUT instruction](http://x86.renejeschke.de/html/file_module_x86_id_222.html) and the [interruption mechanism](http://en.wikipedia.org/wiki/Interrupt). The [Direct Memory Access](http://en.wikipedia.org/wiki/Direct_memory_access) is a fastest solution in practice, but also relies on these primitives. Finally, this corresponds to the [Xen API](http://openmirage.org/wiki/xen-events) design, in the hope that some day Coq could be ported as an unikernel like OCaml with [MirageOS](http://www.openmirage.org/).

### Implementation
The implementation of this DSL is two folds. In Coq, a `run` function gives an executable semantics of the computations. We also compile Coq programs to OCaml using a customized version of the [extraction mechanism](http://www.pps.univ-paris-diderot.fr/~letouzey/download/letouzey_extr_cie08.pdf) of Coq. The impure operators are compiled to impure OCaml operators realizing the effects, like sending messages to the OS.

The impure effects can be classified into three categories:

* memory
* exiting
* asynchronous calls

### Correction
...

## OPAM libraries
...

## Future work
...

Note: *Pluto is also the only planet discovered and undiscovered by the Americans. The [New Horizons](http://en.wikipedia.org/wiki/New_Horizons) space probe should allow us to know more about this mysterious object.*
