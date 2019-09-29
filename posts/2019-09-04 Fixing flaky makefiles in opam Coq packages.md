In [opam](https://opam.ocaml.org/), some packages fail to install _sometimes_. This is a problem because these bugs are hard to reproduce. Yet the user may get the impression that some packages are broken. We show how we listed and then corrected these bugs. The [opam Coq repository](https://github.com/coq/opam-coq-archive) should now be more stable.

### Round 1
At first we (I) did not know how to fix these installation bugs. They would typically result in OCaml errors such as:

    The following actions will be performed:
      - install coq-rational 8.6.0
    [...]
    - File "Rewrite/LeibnizRewrite/AC/aC.ml", line 1:
    - Error: Corrupted compiled interface

in `coq-rational.8.6.0`. As we ran opam with the option `-j1` (one parallel build), this did not seem like a concurrency bug. We decided to add a [black-list file](https://github.com/coq-bench/make-html/blob/master/black_list.rb) to the [Coq opam bench](https://coq-bench.github.io/) to list out and hide these bugs. This was not a perfect solution, but at least it did not flood the results with non-reproducible errors.

### Round 2
As noticed by [Karl Palmskog](https://setoid.com/), the opam builds were running in parallel despite the `-j1` option. As a proof, the presence in the installation traces of:

    make[2]: *** Waiting for unfinished jobs....

This was due to a bug in opam, [corrected in version `2.0.5`](https://github.com/ocaml/opam/blob/2.0.5/CHANGES#L10). Thus the fix was just to replace:

    [make "-j%{jobs}%"]

by:

    [make]

in each package definition with parallel build issues.

These errors occurred in most of the packages using [coq_makefile](https://coq.inria.fr/refman/practical-tools/utilities.html#building-a-coq-project-with-coq-makefile) and mixing Coq and OCaml code. The versions `4.02` and `4.05` of OCaml were impacted, but the version `4.07` seems free of bugs. The most frequent error message is `Corrupted compiled interface`. Apparently this happens when both `byte` and `opt` compilations run in parallel, modifying `.cmi` files at the same time. The [Dune](https://dune.build/) build system may be a more robust alternative to `coq_makefile`, but I have no data about it.

### Result
Most of the Coq packages with flaky makefiles are now corrected, and the respective maintainers contacted. We will continue to fix these bugs as they occur.
