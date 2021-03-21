The [coq-of-ocaml](https://github.com/clarus/coq-of-ocaml) compiler transforms [OCaml](https://ocaml.org/) programs to [Coq](https://coq.inria.fr/) ones. There usually are many errors in each file to import (the Coq language tends to be stricter than OCaml and we do not want to import code with too much encoding). Fixing errors may be the most time consuming part of an import. We present a system to display all the errors at once instead of one by one. We believe that it helps to get a quick idea of how difficult a file is to translate, while having a sense of progress when fixing the errors.

> We develop [coq-of-ocaml]((https://clarus.github.io/coq-of-ocaml/)) at [🐙&nbsp;Nomadic&nbsp;Labs](https://www.nomadic-labs.com/) with the aim to formally verify OCaml programs, and in particular the implementation of the crypto-currency [Tezos](https://tezos.com/). If you want to use this tool for your own projects, please do not hesitate to look at our [website](https://clarus.github.io/coq-of-ocaml/) or [contact us](mailto:contact@nomadic-labs.com)!

![Multiple errors report](static/images/coq-of-ocaml-multiple-errors/report.png "Multiple errors report")

## Example
Take this perfectly valid OCaml program:

    let foo x =
      if x then
        assert false (* no assert in Coq *)
      else begin
        print_endline "bar"; (* no sequencing of side-effects in Coq *)
        true
      end

We would like to report that both the `assert` and the sequencing of effects with `;` are not available in Coq.

To import programs, `coq-of-ocaml` runs a single pass on the OCaml's typed abstract syntax tree. During the recursive exploration of the syntax tree, we would like to explore both branches of the `if` to report both errors. We need a way to accumulate errors along the way and not block at the first mistake. Since `coq-of-ocaml` has a single pass, we hope to get most of the errors doing so.

## An error monad
To encapsulate the error handling mechanism, we define the following [free monad](https://stackoverflow.com/a/13388966/3873794) in OCaml (`coq-of-ocaml` is implemented in OCaml):

    module Command = struct
      type 'a t =
        | GetEnv : Env.t t
        | Raise : Error.Category.t * string -> 'a t
    end

    module Wrapper = struct
      type t =
        | SetEnv of Env.t
        | SetLoc of Loc.t
    end

    type 'a t =
      | All : 'a t * 'b t -> ('a * 'b) t
      | Bind : 'b t * ('b -> 'a t) -> 'a t
      | Command of 'a Command.t
      | Return of 'a
      | Wrapper of Wrapper.t * 'a t

There are three main constructs to note:

* `All` which combines the results of two computations, both of which may fail. It allows to accumulate errors in each branch of the syntax tree;
* `Command`, especially the case `Raise` to create an error at the current code location;
* `Wrapper`, especially the case `SetLoc` to set the current code location in (and only in) the following computation.

We also have primitives `GetEnv` and `SetEnv` to manipulate the current OCaml environment from the AST. The `Bind` and `Return` are the standard monadic primitives. We chose a free-monad in order to isolate the definition of side-effects and, one day, import `coq-of-ocaml` to Coq. 

We rewrote `coq-of-ocaml` using the `All` primitive as much as possible (typically when two computations were not depending on each other). Since the current OCaml environment and location are handled by the monad, we cleaned the code to propagate their values. Having done that, retrieving the complete list of errors was mostly given for free.

## A nice output
In order to present a nice output to the user, we decided to do the following:

* add colors;
* show the code extract where the error comes from, using a presentation similar to the JavaScript's [@babel/code-frame](https://babeljs.io/docs/en/next/babel-code-frame.html) (for now an error location is a line; we plan to precise the column and add multiline support);
* clearly separate errors with a long line and some spaces;
* add an error category (side-effect, dependency not found, ...).

Some of these changes were inspired by the [Elm](https://elm-lang.org/) blog post on producing [Compiler Errors for Humans](https://elm-lang.org/news/compiler-errors-for-humans).
