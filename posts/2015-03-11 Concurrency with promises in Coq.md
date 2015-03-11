We will present two primitives to write concurrent (and interactive) programs in [Coq](http://coq.inria.fr/), using the concept of [promises](http://en.wikipedia.org/wiki/Futures_and_promises). We will also show how to formally verify programs written using promises.

## Primitives for concurrency
To write an application doing inputs--outputs, we quickly need some sorts of non-blocking ways to do inputs--outputs. There are many approaches to do concurrency, for example:

* blocking calls in system threads
* the main event loop
* callbacks in lightweight threads
* [promises](http://en.wikipedia.org/wiki/Futures_and_promises)
* the [actor model](http://en.wikipedia.org/wiki/Actor_model)

We will use promises to start with, in the style of the [Lwt library](http://ocsigen.org/lwt/) for [lightweight threads](http://en.wikipedia.org/wiki/Light-weight_process) in [OCaml](https://ocaml.org/). The promises have the advantage to be implemented with an event loop instead of with system threads, while being simpler to use than an event loop or callbacks. The actor model is another interesting approach which we will study later.

### Sequential computations
We recall the definition of our interactive sequential computation (see the [coq:io](https://github.com/clarus/io) package):

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

The effects are a type of `command` and a type of `answer`, dependent on the corresponding command. A computation of type `C.t E A` is a computation returning a value of type `A`. It can be of three forms:

* `Ret x`, the pure value `x`
* `Call command`, the call to a command
* `Let x f`, the evaluation of `x`, followed by the evaluation of `f` applied to the result of `x`

The `Let` operator is also called the *bind* in [monads](http://en.wikipedia.org/wiki/Monad_%28functional_programming%29) terminology. The `Effects.t` typically represent external calls to the system. You can for example look at the [documentation](http://clarus.github.io/doc/io-system/Io.System.System.html) of the [coq:io:system](https://github.com/clarus/io-system) library.

### Join
We add the `Join` operator to the computations:

    | Join : forall {A B : Type}, t E A -> t E B -> t E (A * B)

The program `Join x y` runs the two computations `x` and `y` in parallel and returns the couple of their results. Since the two computations are launched concurrently, blocking calls made in `x` will not block calls in `y`. This is the main operator we will use to write concurrent programs.

Note that since our programs are pure, there are no shared states between `x` and `y`. We will see in a future post how to handle a shared state with concurrency in Coq.

### First
The `First` operator is defined as:

    | First : forall {A B : Type}, t E A -> t E B -> t E (A + B)

The program `First x y` runs the two computations `x` and `y` in parallel and returns the result of the first one which terminated. The other one is canceled.

This operator is dangerous because one of your computations may get canceled. It is mainly there to implement timeouts. To run a computation `slow` which may not terminate or take too much time, we can combine it with a timeout, writing something like:

    First slow (sleep 10)

to make sure the program terminates after 10 seconds, if `sleep 10` is the computation which does nothing but terminating after 10 seconds.

## Specification of promises

