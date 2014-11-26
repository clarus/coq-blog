[Pluto](https://github.com/coq-concurrency/pluto) is the first web server written in [Coq](https://coq.inria.fr/).

It is a research project which aims to apply the pure and dependently typed [Coq](https://coq.inria.fr/) language to system programming, with inputs/outputs and fine grained concurrency in mind. This kind of programming is particularly error-prone and hard to test, due to non-determinism and interactions with the external world. Moreover, such programs like servers and databases can manipulate critical data, for example in a professional environment. We try to develop new programming techniques with an extremist and purely functional approach, in the hope to lead to safer systems.

For now Pluto can serve static websites, using event-based I/Os and lightweight threads to handle concurrent requests.

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
Coq is a pure language so it cannot directly express concurrency and I/Os. For that we use a Domain Specific Language (DSL) with new primitive constructs to describe impure computations. The architecture is implemented in the [Coq concurrency - system](https://github.com/coq-concurrency/system) project.

### Operators
The `Read` and `Write` commands read or update atomically global references (shared by all the threads). `Ret` lifts a pure Coq expression, `Bind` sequences two computations. The `Send` constructor does an asynchronous call to the OS. It provides a handler with its own private memory (a lightweight thread), called each time an answer is sent to the request. The `Exit` command halts the program and stops all pending handlers.

We decided to use fully asynchronous I/Os with lightweight threads for two reasons:

* it is generally considered more efficient than synchronous system-calls plus system-threads (see the evolution from the [Apache](http://www.apache.org/) 1 multi-threaded server to mono-threaded event-driven systems like [Node.js](http://nodejs.org/))
* it corresponds more to what computers intrinsically are: the most primitive communication facilities on microprocessors are the [OUT instruction](http://x86.renejeschke.de/html/file_module_x86_id_222.html) and the [interruption mechanism](http://en.wikipedia.org/wiki/Interrupt). The [Direct Memory Access](http://en.wikipedia.org/wiki/Direct_memory_access) is a fastest solution in practice, but also relies on these primitives. Finally, this corresponds to the [Xen API](http://openmirage.org/wiki/xen-events) design, in the hope that some day Coq could be ported as an unikernel like OCaml with [MirageOS](http://www.openmirage.org/).

### Implementation
The implementation of this DSL is two folds. In Coq, a `run` function gives an executable semantics of the computations. The existence of an executable semantics is an improvement over other works which only give unrealized axioms for I/Os effects (for example in Haskell or in Idris, see [IO.idr](https://github.com/idris-lang/Idris-dev/blob/master/libs/prelude/IO.idr)).

We also compile Coq programs to OCaml using a customized version of the [extraction mechanism](http://www.pps.univ-paris-diderot.fr/~letouzey/download/letouzey_extr_cie08.pdf) of Coq. The impure operators are compiled to impure OCaml operators realizing the effects, like sending messages to the OS.

The impure effects can be classified into three categories:

* memory
* exit
* asynchronous calls

The memory and exit effects are implemented (both in Coq and OCaml) by the monadic transformations of the state and exception monads (see [monadic transformations](http://gallium.inria.fr/~xleroy/mpri/progfunc/monads.2up.pdf)).

In Coq, the asynchronous calls are represented by a monad reader and a monad writer. The system-calls are typed, and to each request type corresponds one answer type. The handlers are stored into a heap and must have a type compatible with their request. They have their own private memory (implemented as a state monad), and can be called an unbounded number of times (for example, with a web server, the socket listener will get as many inputs as connecting clients). A handler can also disconnect itself to be garbage collected.

In OCaml, the handlers are stored in the heap extracted from the Coq implementation. Communication with the OS occurs through a unique bidirectional pipe. The `Send` method writes a message on the pipe. A single loop listens synchronously to the pipe, and dispatches the events to the handlers. All messages are serialized into strings. At the other end of the pipe sits a [proxy](https://github.com/coq-concurrency/proxy). The proxy parses the messages and translates them into real system-calls. It is implemented in OCaml using [Lwt](http://ocsigen.org/lwt/). Note that Lwt is not used as a lightweight threads library, but as an asynchronous API to Unix. For a more technical discussion about asynchronous system-calls in Unix, you can read this [paper](http://www.pps.univ-paris-diderot.fr/~jch/research/cpc-2012.pdf) of Kerneis and Chroboczek.

![Schema](static/images/pluto_runtime.svg)

### Correction
There is no mechanism to prove properties about the effects yet (I/Os, shared memory, ...). However it is possible to certify the functional part of the server, or any interactive Coq application based on our runtime, using standard techniques in Coq (see for example the [Program extension](http://www.pps.univ-paris-diderot.fr/~sozeau/research/publications/Program-ing_Finger_Trees_in_Coq.pdf) of Matthieu Sozeau).

We can also question the correctness of the compilation to OCaml, or whether the `run` function in Coq is faithful to the extracted code. We have no formal proof, but we designed the system with correctness in mind. In particular, we designed our DSL with a minimal "attack surface". The memory, the lightweight threads, the exit effect are compiled by monadic transformation in Coq and then using the standard extraction mechanism. For I/Os, there is no abstract `World` type which could lead to duplication in Coq. We just use a monad reader and monad writer, and messages are sent or read into a pipe. On the long term, we could dream of a formally proven Coq compiler and adapt it to our customized compilation of read/write effects.

## Code extracts
This is the main function of the server, in [pluto/Pluto.v](https://github.com/coq-concurrency/pluto/blob/master/Pluto.v):

    Definition program (argv : list LString.t) : C.t [] unit :=
      match argv with
      | [_; port; website_dir] =>
        match LString.to_N 10 port with
        | None => print_usage tt
        | Some port_number =>
          Time.get (fun time =>
          let time := Moment.Print.rfc1123 @@ Moment.of_epoch @@ Z.of_N time in
          let welcome_message := LString.s "Pluto starting on " ++ website_dir ++
            LString.s ", port " ++ port ++
            LString.s ", on " ++ time ++ LString.s "." in
          Log.write welcome_message (fun _ =>
          ServerSocket.bind port_number (fun client =>
            match client with
            | None =>
              Log.write (LString.s "Server socket failed.") (fun _ => C.Exit tt)
            | Some client => handle_client website_dir client
            end)))
        end
      | _ => print_usage tt
      end.

The program is parametrized by the list of the command-line arguments. The return type is `C.t [] unit`, the type of computations returning `unit` with an empty shared memory (`[]` means that the list of memory cells is empty).

We first check that there are two arguments, the first one being an integer (the port number). Else we print a usage message and exit. Then we request the current time to log it. The definition of `Time.get` is in [system/StdLib.v](https://github.com/coq-concurrency/system/blob/master/StdLib.v):

    (** Get the current time (the number of seconds since Unix epoch). *)
    Definition get {sig : Signature.t} (handler : N -> C.t sig unit)
      : C.t sig unit :=
      C.Send Command.Time tt tt (fun _ time =>
        do! handler time in
        C.Ret None).

The function `get` is parametrized by a handler `N -> C.t sig unit` which is a computation receiving the time in seconds. The `handler` is called when the OS responds to the `C.Send` operator, calling the callback `fun _ time => do! handler time in C.Ret None`. This callback has no private memory (actually a private memory of type `unit` initialized to `tt`). The callback always returns `None` to disconnect itself after an answer (so that the handler is called at most once, even if the OS is bugged and responds several times to the `Command.Time` request).

We log the current time in RFC 1123 format with a welcome message and bind to the server socket. The handler is listening while there are new clients connecting, and runs the `handle_client` method for each. This program may never terminate, while we are writing pure Coq without explicit non-termination monad. The non-termination effect is provided by the monad reader, which is compiled to OCaml as an infinite loop listening to the system pipe.

## Future work
We learn many things writing a realistic example of a web server in Coq, especially in the way of implementing side effects. We also shown that it is possible to use Coq as a programming language to write interactive and concurrent softwares.

Our main goal now is to extend our DSL of computations with a specification and a certification mechanism. We would like to write a specification of the non-purely functional part of our web server and prove its correctness, exploiting the unique ability of Coq to marry proofs and programs.

Note: *Pluto is also the only planet discovered and undiscovered by the Americans. The [New Horizons](http://en.wikipedia.org/wiki/New_Horizons) space probe should give us more insights about this mysterious object.*
