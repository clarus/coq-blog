Concurrent programs with inputs/outputs are hard to test: they are non-deterministic and interact with the outside world. They are even harder to formally specify completely, and prove correct. We present (what we believe to be) a novel approach to check such programs doing symbolic simulations in [Coq](https://coq.inria.fr/).

Symbolic simulations are like deterministic simulations one concrete data, using some symbolic values to actually run and check the results of a *full set* of simulations. Here is a good talk about testing real systems by simulation: [Testing Distributed Systems with Deterministic Simulation](https://foundationdb.com/videos/testing-distributed-systems-with-deterministic-simulation). We use the Coq's pure programming language Gallina to describe the behavior of a program's environment, which can include the user, the operating system, other connected computers, ... The environment is responsible for two things:

* feeding data to the program
* checking that its answers verify some properties

We hope this approach will provide a good compromise between full specifications and testing on single data instances. We will define a simple concurrent calculus and give some small examples.

All the following Coq samples are in [coq-concurrency/system#simulation-callbacks](https://github.com/coq-concurrency/system/tree/simulation-callbacks).

## Calculus with handlers
To allow simpler reasoning, we want our calculus to be somehow "deterministic". By removing shared mutable variables we remove all the sources of non-determinism, except the order of the input events. However, having shared mutable states is often useful, typically to implement a data storage. Still, we will try to go as far as possible without mutable state.

An other way to reduce non-determinism is to restrict the way we are waiting for events and doing threads. We define a calculus with only asynchronous calls and forks (without joins):

    Inductive t : Type :=
    | Ret : t
    | Par : t -> t -> t
    | Send : forall (command : Command.t), Command.request command ->
      (Command.answer command -> t) -> t.

A computation can be:

* `Ret`: do nothing
* `Par c1 c2`: start `c1` and `c2` in parallel
* `Send command request (fun answer => c)`: emit a request `request` of kind `command` with a handler for the answer

Here is the classical Hello World:

    Definition hello_world : C.t :=
      do! Command.Write @ LString.s "Hello world!" in
      C.Ret.

We use the notation `do! command @ request in e` for `Send command request (fun _ => e)`.

We can do a simple echo program which repeats one user input:

    Definition echo : C.t :=
      let! message := Command.Read @ tt in
      do! Command.Write @ message in
      C.Ret.

The `let!` is like the `do!` but naming the argument of the handler.

These examples are executed sequentially. In practice, they may not terminate if the operating system never answers to the requests. There can be at most one answer per request. We need to use a fixpoint to handle several requests in parallel:

    Fixpoint echo_par (fuel : nat) : C.t :=
      match fuel with
      | O => C.Ret
      | S fuel => C.Par echo (echo_par fuel)
      end.

This program concurrently wait for `fuel` user inputs, print them and stop.

## Simulations
A simulation is a co-program over a concurrent and interactive program. It answers to the requests of the program, playing the role of the environment:

    Inductive t : C.t -> Type :=
    | Ret : t C.Ret
    | Par : forall {c1 c2 : C.t}, t c1 -> t c2 -> t (C.Par c1 c2)
    | Send : forall (command : Command.t) (request : Command.request command)
      (answer : Command.answer command) {handler : Command.answer command -> C.t},
      t (handler answer) -> t (C.Send command request handler).

A simulation, or a run, is defined by induction over the program's structure. This has two advantages:

* by construction, a simulation must give exactly one answer per request
* you can construct the simulation following the structure of the program

For convenience, we use the tactic mode of Coq to build simulations. Doing so, we get a kind of interactive and symbolic debugger for our program. This helps writing meaningful simulations. Here is the simulation of Hello World:

    Definition hello_world_run : Run.t hello_world.
      apply (Run.Send Command.Write (LString.s "Hello world!") tt).
      exact Run.Ret.
    Defined.

This simulation checks that the program `hello_world` does exactly one thing: sending the message `"Hello world!"`. For the echo of one message:

    Definition run_echo (message : LString.t) : Run.t echo.
      apply (Run.Send Command.Read tt message).
      apply (Run.Send Command.Write message tt).
      exact Run.Ret.
    Defined.

We check that, for any message entered by the user, the program will only print this message. Given a list of messages, we can construct a set of simulations for the concurrent echo:

    Fixpoint run_echo_par (messages : list LString.t)
      : Run.t (echo_par (List.length messages)).
      destruct messages as [|message messages].
      - exact Run.Ret.
      - apply Run.Par.
        * exact (run_echo message).
        * exact (run_echo_par messages).
    Defined.

This simulation is recursive to follow the shape of the simulated program. It reuses the simulation `run_echo` of `echo`. The simulation is defined for any order of interleaving of the message events. This is made possible because in this calculus the execution order does not matter.

## Time server
In the file [Simulation.v](https://github.com/coq-concurrency/system/blob/simulation-callbacks/Simulation.v) we give an example of a simple time server. The clients can connect and get the current time of the server. Contrary to the previous examples, we do not cover all possible runs. Instead we give two sets of simulations:

* a first one where the server socket cannot be bound
* a second one where both the server and clients sockets never return an error

We do not cover all the cases, for example the case of a client socket which cannot be written to. We believe this is both a weakness and a strength of this approach. Contrary to a full specification, not all the execution paths are tested. But simulations are simple to write, while covering more cases than traditional tests.

## Future work
We want to extend this method to check more complex programs, like a database or a chat-server. For that we should first extend the expressiveness of the calculus, and so of the simulations.

We would also like to relate this method to the specifications plus proofs approach. A first way could be to have simulations which *by construction* cover all the execution paths. An other way could be to express properties over simulations to enforce a specification over any simulation.
