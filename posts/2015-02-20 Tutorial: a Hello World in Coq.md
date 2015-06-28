We will present the classic [Hello World](http://en.wikipedia.org/wiki/%22Hello,_world!%22_program) program in [Coq](https://coq.inria.fr/). We will explain how to compile, run, and certify interactive programs in Coq.

The *Hello World* program exists in almost every languages, including [in White Space](http://en.wikipedia.org/wiki/List_of_Hello_world_program_examples#W). In Coq this is more complicated because the language is purely functional. This means that no effects can be done, in particular no inputs-outputs. This constraint is there to preserve the logical consistency of the system. However, we can still encode inputs-outputs by defining a [monad](http://en.wikipedia.org/wiki/Monad_%28functional_programming%29). This technique was popularized by the [Haskell](http://en.wikipedia.org/wiki/Haskell_%28programming_language%29) programming language.

## Hello World
Using [OPAM for Coq](http://coq-blog.clarus.me/use-opam-for-coq.html), install the package [coq:io:system](https://github.com/clarus/io-system):

    opam repo add coq-released https://coq.inria.fr/opam/released
    opam install coq:io:system

You can now write the *Hello World*:

    Require Import Coq.Lists.List.
    Require Import Io.All.
    Require Import Io.System.All.
    Require Import ListString.All.

    Import ListNotations.
    Import C.Notations.

    (** The classic Hello World program. *)
    Definition hello_world (argv : list LString.t) : C.t System.effect unit :=
      System.log (LString.s "Hello world!").

We load some libraries and write the `hello_world` program by calling the `System.log` function. The return type is `C.t System.effect unit`, which means this is a *impure* computation with *System* effects and returning a value of type `unit`. The command line arguments are given in the list of strings `argv`, but not used here.

To compile the `hello_world` program we add:

    Definition main := Extraction.launch hello_world.
    Extraction "extraction/main" main.

to generate an [OCaml](https://ocaml.org/) file `main.ml`. We compile and run this file:

    ocamlbuild main.native -use-ocamlfind -package io-system
    ./main.native

This should display `Hello world!` on the terminal.

### Specification
The specification of this program is very straightforward: *the program only prints "Hello world!" and quits* (here the specification is as long as the program itself, but this is not always the case). A simple way to write this specification is to describe an environment of the program which reacts to a single event: the printing of the message "Hello world!" on the terminal. You can express this environment as a program:

    (** The Hello World program only says hello. *)
    Definition hello_world_ok (argv : list LString.t) : Run.t (hello_world argv) tt.
      apply (Run.log_ok (LString.s "Hello world!")).
    Defined.

The specification `hello_world_ok` is of type `Run.t (hello_world argv) tt`: this runs the program `hello_world` on an argument `argv` and returns the result `tt`. We just apply the function `Run.log_ok` of the [coq:io:system](https://github.com/clarus/io-system) library which exactly describes an environment reacting to a single printing event.

This specification needs *no* proofs because it is valid *by construction*. We do not need any SMT solver, model checker or manual proof. The specification is valid because it is well-typed. Of course this example is very simple, so we will see a slightly more complex one.

## What is your name?
This program asks for your name and replies with your name:

    (** Ask for the user name and answer hello. *)
    Definition your_name (argv : list LString.t) : C.t System.effect unit :=
      do! System.log (LString.s "What is your name?") in
      let! name := System.read_line in (* Ask the name. *)
      match name with
      | None => ret tt (* In case of error do nothing. *)
      | Some name => System.log (LString.s "Hello " ++ name ++ LString.s "!")
      end.

We see here how to compose impure computations in sequence with the `do!` and `let!` keywords. The construct:

    let! x := e1 in e2

executes `e1`, assigns the result to `x` and then executes `e2`. The `do!` is a syntactic sugar for a `let!` with an empty variable name. We use the `System.read_line` function which gets a new line on the standard input. If the `read_line` operation fails we returns the pure value `tt` using the `ret` operator, else we print the user name on the terminal.

You can run this program as before by compilation to OCaml.

### Specification
We have two [use cases](http://en.wikipedia.org/wiki/Use_case) for the `your_name` program:

* when the user enters a name,
* when the standard input is broken.

For the first use case:

    (** The `your_name` program answers something when you give your name. *)
    Definition your_name_ok (argv : list LString.t) (name : LString.t)
      : Run.t (your_name argv) tt.
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
    Definition your_name_error (argv : list LString.t) : Run.t (your_name argv) tt.
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
