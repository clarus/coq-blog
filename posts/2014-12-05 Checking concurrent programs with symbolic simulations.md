Concurrent programs with inputs/outputs are hard to test: they are non-deterministic and interact with the outside world. They are even harder to formally specify completely, and prove correct. We present (what we believe to be) a novel approach to check such programs doing symbolic simulations in [Coq](https://coq.inria.fr/).

Symbolic simulations are like deterministic simulations one concrete data, using some symbolic values to actually run and check the results of a *full set* of simulations. Here is a good talk about testing real systems by simulation: [Testing Distributed Systems with Deterministic Simulation](https://foundationdb.com/videos/testing-distributed-systems-with-deterministic-simulation). We use the Coq's pure programming language Gallina to describe the behavior of a program's environment, which can include the user, the operating system, other connected computers, ... The environment is responsible for two things:

* feeding data to the program
* checking that its answers verify some properties

We hope this approach will provide a good compromise between full specifications and testing on single data instances. We will define a simple concurrent calculus and give some small examples.

## Calculus with handlers
To allow simpler reasoning, we want our calculus to be somehow "deterministic". By removing shared mutable variables we remove all the sources of non-determinism, except the order of the input events. However, having shared mutable states is often useful, typically to implement a data storage. Still, we will try to go as far as possible without mutable state.

An other way to reduce non-determinism is to restrict the way we are waiting for events and doing threads. We define a calculus with only asynchronous calls and forks (without joins):

    Inductive t : Type :=
    | Ret : t
    | Par : t -> t -> t
    | Send : forall (command : Command.t), Command.request command ->
      (Command.answer command -> t) -> t.

A computation can be:

* `Ret`: does nothing
* `Par c1 c2`: starts `c1` and `c2` in parallel
* `Send command request (fun answer => c)`: emits a request `request` of kind `command` with a handler for the answer

## Simulations

## Examples

## Future work
