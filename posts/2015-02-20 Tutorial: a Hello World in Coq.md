We will present the classic [Hello World](http://en.wikipedia.org/wiki/%22Hello,_world!%22_program) program in [Coq](https://coq.inria.fr/), and explain how to compile and run it. We will also introduce the way you can specify and prove interactive programs in Coq.

The Hello World program exists in almost every languages, including [in White Space](http://en.wikipedia.org/wiki/List_of_Hello_world_program_examples#W). In Coq this is more complicated because the language is purely functional. This means that no effects can be done, in particular no inputs-outputs. This constraint is there to preserve the logical consistency of the system. However, we can still encode inputs-outputs by defining a [monad](http://en.wikipedia.org/wiki/Monad_%28functional_programming%29). This technique was popularized by the [Haskell](http://en.wikipedia.org/wiki/Haskell_%28programming_language%29) programming language.

## Hello World
Using [OPAM for Coq](http://coq-blog.clarus.me/use-opam-for-coq.html), install the package [coq:io-effects:unix](https://github.com/clarus/io-effects-unix):

    opam repo add coq-stable https://github.com/coq/repo-stable.git
    opam install coq:io-effects:unix

You can now write the *Hello World*:

    Require Import Coq.Lists.List.
    Require Import IoEffects.All.
    Require Import IoEffectsUnix.All.
    Require Import ListString.All.

    Import ListNotations.
    Import C.Notations.

    (** The classic Hello World program. *)
    Definition hello_world : C.t Unix.effects unit :=
      Unix.log (LString.s "Hello world!").

We load some libraries and write the `hello_world` program by calling the `Unix.log` function. The return type is `C.t Unix.effects unit`, which means this is a *impure* computation with *Unix* effects and returning a value of type `unit`.

To compile the `hello_world` program we add:

    Definition main := Extraction.Lwt.run (Extraction.eval hello_world).
    Extraction "main" main.

to generate an [OCaml](https://ocaml.org/) file `main.ml`. We compile and run this file:

    ocamlbuild main.native -use-ocamlfind -package io-effects-unix
    ./main.native

This should display `Hello world!` on the terminal.

### Specification
The specification of this program is very simple: *the program only prints "Hello world!" and quits* (here the specification is as long as the program itself, but this is not always the case). The simplest way to write this specification is to describe an environment of the program which reacts to a single event: the printing of the message "Hello world!" on the terminal. You can express this environment as a program:

    (** The Hello World program only says hello. *)
    Definition hello_world_ok : Run.t hello_world tt.
      apply (Run.log_ok (LString.s "Hello world!")).
    Defined.

The specification `hello_world_ok` is of type `Run.t hello_world tt`: this runs the program `hello_world` returning the result `tt`. We apply the function `Run.log_ok` of the effects library which exactly describes an environment reacting to a single printing event.

This specification needs *no* proofs because it is valid *by construction*. We do not need any SMT solver, model checker or manual proof. The specification is valid because it is well-typed. Of course this example is very simple, so we will see a slightly more complex one.

## What is your name?
This program asks for your name and replies with your name:

    (** Ask for the user name and answer hello. *)
    Definition your_name : C.t Unix.effects unit :=
      do! Unix.log (LString.s "What is your name?") in
      let! name := Unix.read_line in (* Ask the name. *)
      match name with
      | None => ret tt (* In case of error do nothing. *)
      | Some name => Unix.log (LString.s "Hello " ++ name ++ LString.s "!")
      end.

We see here how to compose impure computations in sequence with the `do!` and `let!` keywords. The construct:

    let! x := e1 in e2

executes `e1`, assigns the result to `x` and then executes `e2`. The `do!` is a syntactic sugar for a `let!` with an empty variable name. We use the `Unix.read_line` function which gets a new line on the standard input. If the `read_line` operation fails we returns the pure value `tt` using the `ret` operator, else we print the user name on the terminal.

You can run this program as before by compilation to OCaml.

### Specification
We have two [use cases](http://en.wikipedia.org/wiki/Use_case) for the `your_name` program:

* when the user enters a name,
* when the standard input is broken.

For the first use case:

    (** The `your_name` program answers something when you give your name. *)
    Definition your_name_ok (name : LString.t) : Run.t your_name tt.
      apply (Run.Let (Run.log_ok _)).
      apply (Run.Let (Run.read_line_ok name)).
      apply (Run.log_ok _).
    Defined.

The specification is parametrized by a `name` which could be any string. The environment does exactly three steps:

* display something on the terminal (the underscore `_` means any value)
* answer `name` to the event `read_line`
* display something on the terminal

The `Run.Let` command composes two steps. For a failing standard input:

    (** The `your_name` program does nothing more in case of error on stdin. *)
    Definition your_name_error : Run.t your_name tt.
      apply (Run.Let (Run.log_ok _)).
      apply (Run.Let Run.read_line_error).
      apply Run.Ret.
    Defined.

we also give three steps:

* display something on the terminal
* answer by an error to the event `read_line`
* terminate (the command `Run.Ret`)

Again, we do not need to prove anything because the specifications are correct by construction.

Next time we will continue with more tutorials, to help you build and certify realistic interactive applications in Coq.