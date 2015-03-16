[Last time](http://coq-blog.clarus.me/concurrency-with-promises-in-coq.html), we presented two primitives `Join` and `First` to write and specify concurrent programs in [Coq](https://coq.inria.fr/), using the concept of [promises](http://en.wikipedia.org/wiki/Futures_and_promises). We will explain how we implemented these primitives and give examples of concurrent programs.

## Implementation
The promises are available in the package [coq:io](https://github.com/clarus/io), starting from the version `2.1.0`. This package symbolically describes the primitive `Join` and `First`. They must be implemented for each  set of effects.

For example in [coq:io:system](https://github.com/clarus/io-system), which defines effects to interact with the system, we compile all the external calls and the computation primitives to [Lwt](http://ocsigen.org/lwt/) (see [coq:io/src/Extraction.v](https://github.com/clarus/io-system/blob/master/src/Extraction.v)):

    Fixpoint eval {A : Type} (x : C.t System.effects A) : Lwt.t A.
      destruct x as [A x | command | A B x f | A B x y | A B x y].
      - exact (Lwt.ret x).
      - exact (eval_command command).
      - exact (Lwt.bind (eval _ x) (fun x => eval _ (f x))).
      - exact (Lwt.join (eval _ x) (eval _ y)).
      - exact (
          Lwt.bind (Lwt.first (eval _ x) (eval _ y)) (fun s =>
          Lwt.ret @@ Sum.to_coq s)).
    Defined.

This code is written in proof mode, so that we do not care about the `match`/`with` parameters and compile with both Coq 8.4 and 8.5 patterns. The functions `join` and `first` are implemented in [coq:io:system:ocaml/ioSystem.ml](https://github.com/clarus/io-system-ocaml/blob/master/ioSystem.ml) using Lwt primitives. The Lwt primitives needed some wrappers because their types are:

    Lwt.join : unit Lwt.t list -> unit Lwt.t
    Lwt.pick : 'a Lwt.t list -> 'a list Lwt.t

where we needed:

    join : 'a Lwt.t -> 'b Lwt.t -> ('a * 'b) Lwt.t
    first : 'a Lwt.t -> 'b Lwt.t -> ('a, 'b) Sum.t Lwt.t

## Hello World

## Larger example
