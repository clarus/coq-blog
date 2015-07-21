[Coq.io](http://coq.io/) is a library for writing and proving concurrent applications with inputs--outputs in [Coq](https://coq.inria.fr/). In order to centralize the informations about it, I have setup a [website on http://coq.io/](http://coq.io/). I have been lucky to get this domain name, since this gives a direct reference to the [IO monad](https://wiki.haskell.org/IO_inside) of [Haskell](https://www.haskell.org/), which popularized the idea of clean imperative programming in a functional language.

There is a [Getting started](http://coq.io/getting_started.html) page with some basic examples and an introduction to the technique of formal specification by use cases, and links to some reference documentation. The library is still evolving, with three upcoming improvements:

* a type [`C.I.t`](https://github.com/coq-io/io/blob/master/src/C.v) for infinite (co-inductive) computations;
* a type [`Trace.t`](https://github.com/coq-io/io/blob/master/src/Trace.v) for whose who want to separate the specifications from the proofs of use cases;
* a [`Lwt.E`](https://github.com/coq-io/lwt) effect to add arbitrary [Lwt](http://ocsigen.org/lwt/) commands.
