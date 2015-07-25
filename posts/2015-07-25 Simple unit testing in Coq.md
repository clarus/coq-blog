Even if we can prove things in [Coq](http://coq.inria.fr/), [unit testing](https://en.wikipedia.org/wiki/Unit_testing) remains an extremely simple and powerful technique to verify what we write. Thanks to the dependent types, we can run unit tests in Coq at compile time by computing into the types. For example, in:

    Definition test_pred : pred 5 = 4 :=
      eq_refl.

we check that the predecessor of `5` is `4` by saying that they are logically equal. The proof of the equality is its only constructor `eq_refl`. We force the type-checker of Coq to reduce both `pred 5` and `4` to check that they are the same.

Usually we want to check many values, what we can do with a list:

    Require Import Coq.Lists.List.

    Import ListNotations.

    Definition test_pred :
      List.map pred [0; 1; 2; 5] = [0; 0; 1; 4] :=
      eq_refl.

We map the `pred` function on the values `0`, `1`, `2`, `5` and check the results.

## The CUnit package
For functions with several parameters, the trick of the `List.map` function does not work well because of the [currying](https://en.wikipedia.org/wiki/Currying). What need instead is a map over lists of tuples. I made the package [CUnit](https://github.com/clarus/coq-cunit) to provide such a map. Install it with [OPAM](use-opam-for-coq.html):

    opam repo add coq-released https://coq.inria.fr/opam/released
    opam install coq:cunit

Now we can test the `plus` function:

    Require Import Coq.Lists.List.
    Require Import CUnit.All.

    Import ListNotations.

    Definition test_plus : List.map_pair plus
      [(0, 0); (0, 3); (4, 0); (4, 3)] =
      [0; 3; 4; 7] :=
      eq_refl.

The complete list of maps in the package [CUnit](https://github.com/clarus/coq-cunit) is the following:

* `List.map_pair {A B C} (f : A -> B -> C) (l : list (A * B)) : list C`
* `List.map_triple {A B C D} (f : A -> B -> C -> D) (l : list (A * B * C)) : list D`
* `List.map_quad {A B C D E} (f : A -> B -> C -> D -> E) (l : list (A * B * C * D)) : list E`
