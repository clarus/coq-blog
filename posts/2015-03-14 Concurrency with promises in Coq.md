We will present two primitives to write concurrent (and interactive) programs in [Coq](http://coq.inria.fr/), using the concept of [promises](http://en.wikipedia.org/wiki/Futures_and_promises) in the library [Coq.io](http://coq.io/). We will also show how to formally specify programs written using promises.

## Primitives for concurrency
To write an interactive application we quickly need a way to do non-blocking inputs--outputs operations. There are many approaches to do non-blocking operations or concurrency, for example:

* blocking calls in system threads
* a main event loop
* callbacks in lightweight threads
* [promises](http://en.wikipedia.org/wiki/Futures_and_promises)
* the [actor model](http://en.wikipedia.org/wiki/Actor_model)

We chose to use promises, in the style of the [Lwt library](http://ocsigen.org/lwt/) for [lightweight threads](http://en.wikipedia.org/wiki/Light-weight_process) in [OCaml](https://ocaml.org/). The promises can be implemented efficiently using lightweight threads, while being simpler to use than an event loop or callbacks. The actor model is another interesting approach which we will study later.

### Sequential computations
We recall the definition of our interactive sequential computations (see the [coq-io](https://github.com/coq-io/io) package):

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

The effects are a type of `command` and a type of `answer`, dependent on the values of the commands. A computation of type `C.t E A` is a computation returning a value of type `A` with the effects `E`. It can be of three forms:

* `Ret x`, the pure value `x`
* `Call command`, the call to a command
* `Let x f`, the evaluation of `x`, followed by the evaluation of `f` applied to the result of `x`

The `Let` operator is also called the *bind* in the terminology of [monads](http://en.wikipedia.org/wiki/Monad_%28functional_programming%29). The effects `E` typically represent external calls to the system. You can for example look at the [API](http://clarus.github.io/doc/io-system/Io.System.System.html) of the [coq-io-system](https://github.com/coq-io/system) library, which provides basic calls to manipulates files and the terminal.

### Join
We add the `Join` operator to the computations:

    | Join : forall {A B : Type}, t E A -> t E B -> t E (A * B)

The program `Join x y` runs the two computations `x` and `y` in parallel and returns the couple of their results. Since the two computations are launched concurrently, blocking calls made in `x` will not block calls in `y`, and reciprocally. This is the main operator we will use to write concurrent programs.

Note that since our programs are pure, there are no shared states between `x` and `y`. We will see in a future post how to represent a shared state in a concurrent program in Coq.

### First
The `First` operator is defined as:

    | First : forall {A B : Type}, t E A -> t E B -> t E (A + B)

The program `First x y` runs the two computations `x` and `y` in parallel and returns the result of the first which terminated. The other may be canceled.

This operator is dangerous because one of our computations can get canceled. The `First` primitive is mainly there to implement timeouts. If we want to run a computation `slow` which may not terminate or may take too much time, we can combine this computation with a timeout by writing something like:

    First slow (sleep 10)

to make sure the program terminates after 10 seconds (we suppose that `sleep 10` is the computation which does nothing but terminating after 10 seconds).

## Specification of promises
We specify our computations using [use-cases](http://en.wikipedia.org/wiki/Use_case) described by runs:

    Module Run.
      Inductive t : forall {E : Effects.t} {A : Type}, C.t E A -> A -> Type :=
      | Ret : forall {E A} (x : A), t (C.Ret (E := E) x) x
      | Call : forall E (command : Effects.command E) (answer : Effects.answer E command),
        t (C.Call E command) answer
      | Let : forall {E A B} {c_x : C.t E B} {x : B} {c_f : B -> C.t E A} {y : A},
        t c_x x -> t (c_f x) y -> t (C.Let c_x c_f) y.
    End Run.

You can see an example of specification using runs in [Formally verify a script in Coq](http://coq-blog.clarus.me/formally-verify-a-script-in-coq.html). The main idea is that a universally quantified run can be viewed as the formal specification of a use-case. This kind of specification is verified just by typing, using lemma on equalities when the type-checker fails.

A run can be a run of the computation:

* `Ret x`, the pure value `x` returned by the computation
* `Call command`, an answer to this command
* `Let x f`, a run of `x` and a run of `f` applied to the result of the run of `x`

We will extend our definition of runs with new cases for the primitives `Join` and `First`.

### Join
We define the run of a `Join` by:

    | Join : forall {E A B} {c_x : C.t E A} {x : A} {c_y : C.t E B} {y : B},
      t c_x x -> t c_y y -> t (C.Join c_x c_y) (x, y)

This means that a run of `Join x y` is a couple of runs for `x` and `y`. Equivalently, a specification of `Join x y` is a couple of specifications for `x` and for `y`.

*A priori*, the interactions of the threads `x` and `y` are not specified. This is up to the user to express these interactions in the specification, if there are some.

### First
There are two ways to run a `First`:

    | Left : forall {E A B} {c_x : C.t E A} {x : A} {c_y : C.t E B},
      t c_x x -> t (C.First c_x c_y) (inl x)
    | Right : forall {E A B} {c_x : C.t E A} {c_y : C.t E B} {y : B},
      t c_y y -> t (C.First c_x c_y) (inr y)

A run of `First x y` is either a run of `x` (the `Left` case) or a run of `y` (the `Right` case). Equivalently, a specification of `First x y` is a specification of `x` or a specification of `y`.

We could ask: yes, but sometimes both `x` and `y` are actually executed! And if we choose the `Left` case for example, we should program `x` instead of `First x y` to start with. These are the same concerns we may have for the definition of the *logical disjunction* in Coq:

    Inductive or (A B : Prop) : Prop :=
    | or_introl : A -> A \/ B
    | or_intror : B -> A \/ B

    where "A \/ B" := (or A B) : type_scope.

and the reasons of these definitions are similar.

## Next time
[Next time](http://coq-blog.clarus.me/implementation-of-promises-for-coq.html) we will see how to implement the primitives `Join` and `First`, to generate efficient and non-blocking interactive programs written in Coq.
