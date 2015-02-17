We will present the [bench system](http://coq-bench.github.io/) for the [Coq](https://coq.inria.fr/) packages.

[OPAM](http://opam.ocamlpro.com/) is the package manager for Coq, providing today [28 stable](https://github.com/coq/repo-stable/tree/master/packages) and [346 unstable](https://github.com/coq/repo-unstable/tree/master/packages) packages (counting two different versions of a package as two different packages). This number is growing, so we needed a bench system to automatically check that all packages are compiling. The bench system will help both:

* packages developers, to check that their programs are compiling with correct dependency constraints;
* Coq developers, to monitor the changes breaking compatibility.

## Use the bench
The results of the bench are available on [coq-bench.github.io](http://coq-bench.github.io/), using the two installation strategies `clean` and `tree`. The results are presented in a colored table with the installation times for valid packages. The `best` column contains the best score obtained for each package.

We check:

* that packages are well-formed, using our [lint](https://github.com/coq-bench/run/blob/master/lint.rb) checker
* the installation of dependencies (with a timeout of 5 minutes)
* the installation of the package (with a timeout of 30 minutes)
* the removing of the package (by comparing the list of files before installation and after removing)

We record the duration of each operation and compute the installation size.

Because your dependencies may evolve, it is good practice to regularly check the bench results for your packages. The `clean` strategy installs each package in a clean environment whereas the `tree` strategy installs as many packages as possible before to remove incompatible ones. In practice, the `tree` strategy yields more errors because packages are tested in an environment polluted by many other packages.

## Architecture
The bench system is hosted on GitHub in the organization [coq-bench](https://github.com/coq-bench). There are four projects:

* [run](https://github.com/coq-bench/run): run the benchmarks
* [database](https://github.com/coq-bench/database): the backup of the benchmarks
* [make-html](https://github.com/coq-bench/make-html): generate the web pages
* [coq-bench.github.io](https://github.com/coq-bench/coq-bench.github.io): the website itself

### [run](https://github.com/coq-bench/run)
This program runs the benchmarks and is written in Ruby. The entry-point is [long_run.rb](https://github.com/coq-bench/run/blob/master/long_run.rb). For each bench a clean [Docker](https://www.docker.com/) image is generated from the parametrized [Dockerfile.erb](https://github.com/coq-bench/run/blob/master/Dockerfile.erb). Then OCaml, OPAM and Coq are installed, and each package is tested. The packages can be from the stable repository or both the stable and unstable repositories. The results are then saved into the database.

### [database](https://github.com/coq-bench/database)
The database is in the [CSV](http://en.wikipedia.org/wiki/Comma-separated_values) format. There is one file per bench and one row per package. The first row gives a legend for each of the 31 columns.

### [make-html](https://github.com/coq-bench/make-html)
This program generates the static HTML pages from the CSV database and is written in Ruby. For example, to generate the pages of the `clean` results:

    ruby make_html.rb ../database/clean html/clean

### [coq-bench.github.io](https://github.com/coq-bench/coq-bench.github.io)
These are the static HTML pages of the bench website. [GitHub](https://github.com/) provides us a nice and simple way to host web pages from a Git repository using [GitHub Pages](https://pages.github.com/).

## Strategies
There are many possible strategies with respect to the installation order of the packages. The installation order is important because OPAM installs different dependencies in different contexts.

We would like to optimize the installation order to reduce the total execution time of the bench, by always installing and testing the dependencies first, so that no packages are compiled twice. Unfortunately this is not possible. Here is a simple counter example. With the following list of packages:

* `A.1.0.0`
* `A.2.0.0`
* `B.1.0.0` depending on `A` (any versions)
* `C.1.0.0` depending on `A.1.0.0` and `B`
* `C.2.0.0` depending on `A.2.0.0` and `B`

we must compile `B` twice (once with `A.1.0.0` and once with `A.2.0.0`) to test both `C.1.0.0` and `C.2.0.0`.

We provide the two following strategies.

### Clean
This is the simplest strategy. We install each package in a fresh environment. This is the most robust and reproducible strategy. But this is not really optimal for packages with big dependencies because they are always reinstalled from scratch.

### Tree
This is a more complex strategy. We install as many packages as possible until all new packages are incompatible with the current environment. The main source of incompatibility is the fact that we cannot install two packages with the same name but different version numbers. Once we are blocked, we roll-back until new packages are installable.

This strategy is more clever but also more fragile. We use the branch mechanism of Git on the `.opam` folder to switch efficiently between OPAM states. At the end of the process, we obtain a tree of all the Git branches used to explore the packages space. For example, for the stable repository:

    * b99f693 coq:concurrency:pluto.1.0.0
    * a1ff2f1 coq:concurrency:system.1.0.0
    * 27c7b93 coq:moment.1.0.0
    * d950f53 coq:list-string.2.0.0
    | * 4817264 coq:flocq.2.2.0
    | | * 3d4105d coq:flocq.2.3.0
    | |/  
    | | * 544de40 coq:concurrency:proxy.1.0.0
    | | * 9a1989e coq:coqeal:refinements.0.9.1
    | | * 0bfd44f coq:fpmods.0.2.0
    | | * bda2af7 coq:coqeal:theory.0.9.1
    | | * 27aa320 coq:plouffe.1.0.0
    | | * 35961d5 coq:coquelicot.2.0.1
    | | * 89db498 coq:error-handlers.1.0.0
    | | * aa85f8c coq:flocq.2.4.0
    | |/  
    | * 48f33a4 coq:iterable.1.0.0
    | * 0a48735 coq:function-ninjas.1.0.0
    | * e2980d1 coq:list-plus.1.0.0
    | * 4122f1a coq:list-string.1.0.0
    |/  
    * 89705ad coq:math-classes.1.0.2
    * 5d3ec5d coq:math-comp.1.5.0
    * 470eefb coq:ssreflect.1.5.0
    * b0205c8 Initial files.

## Related work
The OPAM for OCaml community did some work to obtain a bench system too. There are:

* [OPAM Weather Service](http://ows.irill.org/): do not install the packages, only check the dependency constraints
* [OPAM Bulk](http://www.recoil.org/~avsm/opam-bulk/): a prototype of bench system
* [OCamlot](https://github.com/ocamllabs/ocamlot): a bench system (abandoned)
