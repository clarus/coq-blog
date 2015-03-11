We will present two simple primitives to write concurrent (and interactive) programs in [Coq](http://coq.inria.fr/). We will show how to verify programs written using these primitive. Finally, we will stress the current limitations of our framework.

## Primitives for concurrency
To write an application doing inputs--outputs, we quickly need some sorts of non-blocking ways to do inputs--outputs. There are many approaches to do concurrency, for example:

* blocking calls in system threads
* the main event loop
* callbacks in lightweight threads
* [promises](http://en.wikipedia.org/wiki/Futures_and_promises)
* the [actor model](http://en.wikipedia.org/wiki/Actor_model)

We will use promises to start with, in the style of the [Lwt library](http://ocsigen.org/lwt/) for [lightweight threads](http://en.wikipedia.org/wiki/Light-weight_process) in [OCaml](https://ocaml.org/). The promises have the advantage to be implemented with an event loop instead of with system threads, while being simpler to use than an event loop or callbacks. The actor model is another interesting approach we will try to study later.

### Sequential computations
We recall the definition of an interactive sequential computation:

    Module C.
      Inductive t (E : Effects.t) : Type -> Type :=
      | Ret : forall {A : Type} (x : A), t E A
      | Call : forall (command : Effects.command E), t E (Effects.answer E command)
      | Let : forall {A B : Type}, t E A -> (A -> t E B) -> t E B.
    End C.

where the effects are defined as:

    Module Effects.
      Record t := New {
        command : Type;
        answer : command -> Type }.
    End Effects.

### Join

### First

## Specification

## Example

## Benchmark
