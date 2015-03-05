Last time, in [Write a script in Coq](http://coq-blog.clarus.me/write-a-script-in-coq.html), we explained how to implement scripts in [Coq](https://coq.inria.fr/) with the example of [repos2web](https://github.com/clarus/repos2web), a website generator for [OPAM](http://opam.ocaml.org/) repositories. We will see how to specify and prove correct this script.

## Unit testing, revisited
A common practice to check programs is to write [unit tests](http://en.wikipedia.org/wiki/Unit_testing). For each function, a test is written to execute it on some particular inputs, and to check that the results are what we expect. On more complex programs, we also need to simulate the inputs--outputs with the users, a database, the network, ... To solve this problem, programmers invented solutions like the [mock objects](http://en.wikipedia.org/wiki/Mock_object), which are basically implementations of fake execution environments.

Unfortunately tests are not exhaustive, since the set of program inputs is usually infinite. Methods like [random testing](http://en.wikipedia.org/wiki/Random_testing) can extend the range of tested configurations, but are always limited to a finite set of inputs.

We will explain how to write tests in Coq by writing *scenarios* which formalize [use cases](http://en.wikipedia.org/wiki/Use_case). We will show that they are always *exhaustive*. This completeness is given us for free, thanks to the strict type-system of Coq: in our settings, a scenario is correct if it is well-typed so there is no need to run it on the (infinite) set of parameters.

**Remark:** some people are used to specify programs with pre/post-conditions or invariants, sometimes expressed with temporal logics, rather than by [use cases](http://en.wikipedia.org/wiki/Use_case). We believe that these approaches are pertinent for algorithms but not for interactive programs, because (from our experience) these forms of specifications are less natural than the specifications by use cases. This seems counter-intuitive because use-cases do not cover all the execution paths. But we have to remember that:

* the Coq type system protects us from bad behaviors in all execution paths anyway,
* there are always hypothesis on the environment, so not all execution paths are interesting,
* the quality of a specification depends on its clarity and its similarity with the human intuition.

## Write the scenarios
