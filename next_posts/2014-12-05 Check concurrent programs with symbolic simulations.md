Concurrent programs with inputs/outputs are hard to test: they are non-deterministic and interact with the outside world. They are even harder to formally specify completely, and prove correct. We present (what we believe to be) a novel approach to check such programs doing symbolic simulations in Coq.

Symbolic simulations are like deterministic simulations one concrete data, using some symbolic values to actually run and check the results of a *full set* of simulations. Here is a good talk about testing real systems by simulation: [Testing Distributed Systems with Deterministic Simulation](https://foundationdb.com/videos/testing-distributed-systems-with-deterministic-simulation). We use the Coq's pure programming language Gallina to describe the behavior off a program's environment, which can include the user, the operating system, other connected computers, ... The environment is responsible for two things:

* feeding data to the program
* checking that its answers verify some properties

We hope this approach will provide a good compromise between testing on single data instances and full specifications. We will present here how we simulate two kinds of concurrent calculus with some small examples.

## Calculus with handlers
Definition.
### Run
### Examples

## Calculus with binds
Definition.
### Run
### Examples

## Application to a web server

## Future work
