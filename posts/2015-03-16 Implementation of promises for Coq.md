[Last time](http://coq-blog.clarus.me/concurrency-with-promises-in-coq.html), we presented two primitives `Join` and `First` to write and specify concurrent programs with [Coq.io](http://coq.io/), using the concept of [promises](http://en.wikipedia.org/wiki/Futures_and_promises). We will explain how we implemented these primitives and give examples of concurrent programs.

## Implementation
The promises are available in the package [coq-io](https://github.com/coq-io/io), starting from the version `2.1.0`. This package symbolically describes the primitive `Join` and `First`. They must be implemented for each  set of effects.

For example, in [coq-io-system](https://github.com/coq-io/system) (which defines effects to interact with the system), we compile all the external calls and the computation primitives to [Lwt](http://ocsigen.org/lwt/) in [coq-io/src/Extraction.v](https://github.com/coq-io/system/blob/master/src/Extraction.v):

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

This code is written in proof mode, so that we do not care about the `match`/`with` parameters and compile with both Coq 8.4 and 8.5 patterns. The functions `join` and `first` are implemented in [coq-io-system-ocaml/ioSystem.ml](https://github.com/coq-io/system-ocaml/blob/master/ioSystem.ml) using Lwt primitives. The Lwt primitives needed some wrappers because their types are:

    Lwt.join : unit Lwt.t list -> unit Lwt.t
    Lwt.pick : 'a Lwt.t list -> 'a list Lwt.t

where we needed:

    join : 'a Lwt.t -> 'b Lwt.t -> ('a * 'b) Lwt.t
    first : 'a Lwt.t -> 'b Lwt.t -> ('a, 'b) Sum.t Lwt.t

## Hello World
You can see a simple example of concurrent program in [coq-hello-world](https://github.com/coq-io/hello-world):

    Definition concurrent_hello_world (argv : list LString.t)
      : C.t System.effects unit :=
      let! _ : unit * unit := join
        (System.log (LString.s "Hello"))
        (System.log (LString.s "World")) in
      ret tt.

You can compile this program by replacing the line:

    Definition main := Extraction.run hello_world.

with:

    Definition main := Extraction.run concurrent_hello_world.

and following the instructions given in the [README.md](https://github.com/coq-io/hello-world/blob/master/README.md). It will display either:

    Hello
    World

or:

    World
    Hello

The specification of this program stays that it does exactly one thing: displaying concurrently `Hello` and `World`:

    Definition concurrent_hello_world_ok (argv : list LString.t)
      : Run.t (concurrent_hello_world argv) tt.
      apply (Run.Let (Run.Join
        (Run.log_ok (LString.s "Hello"))
        (Run.log_ok (LString.s "World")))).
      apply Run.Ret.
    Defined.

## Larger example and drawbacks
In the branch [#join](https://github.com/clarus/repos2web/tree/join) of [repos2web](https://github.com/clarus/repos2web), we modified our website generator for [OPAM](http://opam.ocamlpro.com/) repositories to read the packages descriptions concurrently. Our main modification is to use the `Join` operator in the recursive functions to make concurrent recursive calls:

    Fixpoint get_packages (repository : LString.t) (packages : Packages.t)
      : C FullPackages.t :=
      match packages with
      | [] => ret []
      | package :: packages =>
        let! full_package_full_packages := join
          (get_package repository package)
          (get_packages repository packages) in
        let (full_package, full_packages) := full_package_full_packages in
        ret (full_package :: full_packages)
      end.

The specifications are updated similarly.

We tried to run this program on large generated repositories, to see if we gained performances. Unfortunately, after a couple of thousands of packages, we hit the limit of number of files we can open at the same time. We could have a finer control of the concurrency with, for example, a bounded pool of light-weight threads, or by handling the `EMFILE` exception ("too many open files") to retry again later.

We feel that the specification of the Linux system API is quite complex, with many corner cases in practice (like this limit on the number of opened files). These corner cases are hard to be spotted by formal specifications, since the specification of Linux seems complex. Thus programming on top of Linux does not benefit as much as we could hope from formal specifications.

Next, we would like to investigate more the [Xen](http://www.xenproject.org/) API which seems cleaner, completely event-driven and available in [OCaml](https://ocaml.org/) thanks to the [MirageOS](http://www.openmirage.org/) project.
