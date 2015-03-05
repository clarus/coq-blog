Last time, in [Write a script in Coq](http://coq-blog.clarus.me/write-a-script-in-coq.html), we explained how to implement scripts in [Coq](https://coq.inria.fr/) with the example of [repos2web](https://github.com/clarus/repos2web), a website generator for [OPAM](http://opam.ocaml.org/) repositories. We will see how to specify and prove correct this script.

## Unit testing, revisited
A common practice to check programs is to write [unit tests](http://en.wikipedia.org/wiki/Unit_testing). For each function, a test is written to execute it on some particular inputs, and to check that the results are what we expect. On more complex programs, we also need to simulate the inputs--outputs with the users, a database, the network, ... To solve this problem, programmers invented solutions like the [mock objects](http://en.wikipedia.org/wiki/Mock_object), which are basically implementations of fake execution environments.

Unfortunately tests are not exhaustive, since the set of program inputs is usually infinite. Methods like [random testing](http://en.wikipedia.org/wiki/Random_testing) can extend the range of tested configurations, but are always limited to a finite set of inputs.

We will explain how to write tests in Coq by writing *scenarios* which formalize [use cases](http://en.wikipedia.org/wiki/Use_case). We will show that they are always *exhaustive*. This completeness is given us for free, thanks to the strict type-system of Coq: in our settings, a scenario is correct if it is well-typed so there is no need to run it on its (infinite) set of parameters.

**Remark:** some people are used to specify programs with pre/post-conditions or invariants, rather than by [use cases](http://en.wikipedia.org/wiki/Use_case). We believe that these approaches are pertinent for algorithms but not for interactive programs, because (from our experience) these forms of specifications are less natural than the specifications by use cases. This seems counter-intuitive because use-cases do not cover all the execution paths. But we have to remember that:

* the Coq type system protects us from bad behaviors in all execution paths anyway,
* there are always hypothesis on the environment, so not all execution paths are interesting,
* the quality of a specification depends on its clarity and its similarities with the human intuition.

To the best of our knowledge, Coq is the only language with formal verification of use cases.

## Write the scenarios
We write our scenarios in [src/Scenarios.v](https://github.com/clarus/repos2web/blob/master/src/Scenarios.v). There is at least one scenario per function, for the cases in which the environment has no bugs (no file system errors) and the repository architecture is well-formed. For example, for the function:

    Definition get_packages (repository : LString.t) : C (option Packages.t) :=
      let! names := list_coq_files repository in
      match names with
      | None => ret None
      | Some names => get_packages_of_names repository names
      end.

we write the following scenario:

    Definition get_packages_ok (repository : LString.t) (packages : Packages.t)
      : Run.t (get_packages repository) (Some packages).
      apply (Let (list_coq_files_ok _ (Packages.to_folders packages))).
      apply (get_packages_of_names_ok repository packages).
    Defined.

### What does this mean?

This scenario is parametrized by any `repository` folder names and any lists of OPAM `packages`. It runs the function `get_packages` on `repository` and ensures that the result is `Some packages`, meaning that the repository was successfully parsed.

The `get_package` function starts by a `let!` to call `list_coq_files`. We first reuse the scenario `list_coq_files_ok`. This describes a use case in which a list of folders starting by `coq:` is correctly listed:

    apply (Let (list_coq_files_ok _ (Packages.to_folders packages))).

Since this scenario states that the result is `Some files`:

    Definition list_coq_files_ok (folder : LString.t) (files : list Name.t)
      : Run.t (list_coq_files folder) (Some files).

we know that the function `get_packages` will call the function `get_packages_of_names`. We then apply its scenario:

    apply (get_packages_of_names_ok repository packages).

Since Coq tells us there nothing more to do, we conclude by:

    Defined.

The Coq type-checker accepts our scenario which means it is valid: we do not need to run it on every `(repository, packages)` tuples. Even if we were in the tactical mode, we did not need to write any proofs: the scenario is valid *by-construction*. In some cases proofs are required though, to help the type-checker with non-trivial equalities. See for example the `list_coq_files_ok` scenario.

### What did we prove?
We proved that, for any list of OPAM packages, given the "right answers" from the file system, the function `get_packages` will terminate without errors and will return `Some packages`. The "right answers" are defined by giving the "right answers" to `list_coq_files` and then giving the "right answers" to `get_packages_of_names`.

## Next time
We have seen how to formally verify an interactive program in Coq. Next time we will see how to optimize this program using concurrency.
