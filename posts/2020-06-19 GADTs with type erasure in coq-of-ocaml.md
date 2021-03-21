[coq-of-ocaml](https://clarus.github.io/coq-of-ocaml/) is a compiler from the [OCaml](https://ocaml.org/) language to [Coq](https://coq.inria.fr/). It now supports the conversion of the [full Tezos protocol](https://clarus.github.io/coq-of-ocaml/examples/tezos/), composed of around 35.000 lines of code. The [OCaml's GADTs](https://caml.inria.fr/pub/docs/manual-ocaml/gadts.html) are a challenge to compile, as they have no direct equivalent in Coq. We present how we currently convert the GADTs, and especially the new mechanism of type erasure propagation.

> We develop [coq-of-ocaml]((https://clarus.github.io/coq-of-ocaml/)) at [🐙&nbsp;Nomadic&nbsp;Labs](https://www.nomadic-labs.com/) with the aim to formally verify OCaml programs, and in particular the implementation of the crypto-currency [Tezos](https://tezos.com/). If you want to use this tool for your own projects, please do not hesitate to look at our [website](https://clarus.github.io/coq-of-ocaml/) or [contact us](mailto:contact@nomadic-labs.com)!

## Introduction
Let us look at a short example of GADT which we cannot directly compile to Coq. If we define the annotated trees of integers with a&nbsp;`sum` function for trees of two elements:

    type _ t =
      | Leaf : int -> int t
      | Node : 'a t * 'b t -> ('a * 'b) t

    let sum (tree : (int * int) t) : int =
      match tree with
      | Node (Leaf x, Leaf y) -> x + y

a direct translation to Coq could be:

    Inductive t : Set -> Set :=
    | Leaf : Z -> t Z
    | Node : forall {A B : Set}, t A -> t B -> t (A * B).

    Definition sum (tree : t (Z * Z)) : Z :=
      match tree with
      | Node (Leaf x) (Leaf y) => x + y
      end.

but this causes the following error:

    Error: Non exhaustive pattern-matching: no clause found for pattern Leaf _

Coq cannot decide that this pattern-matching is exhaustive because types are not comparable in Coq. One could even add an axiom stating that:

    Z = Z * Z

and we could not derive a contradiction as these two types have the same cardinality. See this [discussion](https://coq.discourse.group/t/inequality-between-types/106) on type equality for more information. A solution with dependent types could be to use tags (which are values) to annotate the type&nbsp;`t`. We can say that with dependent types we "match values" while with GADTs we "unify types".

Another issue is the fact that OCaml unifies polymorphic type variables of other values in the&nbsp;`match`. In Coq we can use the [convoy pattern](http://adam.chlipala.net/cpdt/html/MoreDep.html) to achieve similar results. Finally, having a type appearing as a type parameter for itself in a GADT definition may break the strict positivity constraint and make Coq to refuse the type definition.

The main idea of our solution is to erase the type parameters of the GADTs. When there is a match with a GADT value, we need a way to get back the information we lost erasing the types. Using OCaml attributes to guide coq-of-ocaml, the user can add in the generated code:

* a `match` branch for the impossible cases;
* some casts on the variables introduced by the `match` patterns;
* a cast on the results of the `match` branches.

We define the impossible `match` branch result and the casts operators in Coq using axioms.

We transitively propagate the type erasures from GADTs and phantom types. Erasing unused type variables is important in order not to block the type inference mechanism of Coq. Indeed, when a type variable is not used:

    Definition id_nat {A : Set} (n : nat) : nat := n.

    Definition one := id_nat 1.

Coq often reacts with the following error:

    > Definition one := id_nat 1.
    >                   ^^^^^^
    Error: Cannot infer the implicit parameter A of id_nat whose type is "Set".

even if any set could fit for `A`.

## Definition of types
We consider an algebraic type definition in OCaml to be a GADT if the return type parameters of some constructors are not (different) polymorphic type variables. Here is an example of GADT:

    type _ expr =
      | Int : int -> int expr
      | Couple : 'a expr * 'b expr -> ('a * 'b) expr

This is not a GADT:

    type 'loc ast =
      | Const : int * 'loc -> 'loc ast
      | Add : 'loc ast * 'loc ast * 'loc -> 'loc ast

We could also write `'loc ast` with the `of` syntax:

    type 'loc ast =
      | Const of int * 'loc
      | Add of 'loc ast * 'loc ast * 'loc

We do not consider the `printable` type to be a GADT:

    type printable =
      | Printable : 'a * ('a -> string) -> printable

The reason why we define the type `printable` with the GADT syntax in OCaml is because there is an existential type variable `'a`.

We transform the previous types into the following Coq code:

    Inductive expr : Set :=
    | Int : int -> expr
    | Couple : expr -> expr -> expr.

    Inductive ast (loc : Set) : Set :=
    | Const : int -> loc -> ast loc
    | Add : ast loc -> ast loc -> loc -> ast loc.

    Arguments Const {_}.
    Arguments Add {_}.

    Inductive printable : Set :=
    | Printable : forall {a : Set}, a -> (a -> string) -> printable.

For the `expr` type we remove the type parameter. Note that it does not change the information available at runtime. We transform the `ast` type keeping the type parameter `loc`. We use a `forall` quantifier in the `Printable` constructor to encode the existential type variable `a`.

## Type expressions
We apply the erasure of unused types to type expressions. For example, with the following OCaml code:

    type 'a num = int

    type 'a num_with_label = 'a num * string

    let add_label (n : 'a num) =
      (n, string_of_int n)

we generate the Coq code:

    Definition num : Set := int.

    Definition num_with_label : Set := num * string.

    Definition add_label (n : num) : num_with_label :=
      (n, (OCaml.Stdlib.string_of_int n)).

We consider a type parameter to be unused if:

* it does not appear in the type expression (such as in `num`), or;
* is a GADT type parameter, or;
* is only used by types which do not use their argument (such as in `num_with_label`).

Thanks to this propagation of erasure, we limit the number of type parameters appearing in the generated types. This is helpful because with the erasure of GADT parameters many types become useless in Coq and clutter the output. It also reduces the number of type errors during type inference for unused implicit type parameters, as we have seen in the introduction.

## Pattern matching
By default, we only do a syntactic transformation from pattern matching in OCaml to pattern matching in Coq. We encode the `when` clauses with an additional boolean parameter:

    let is_positive x =
      match x with
      | Ok n when n >= 0 -> true
      | _ -> false

is transformed to:

    Definition is_positive {A : Set} (x : sum int A) : bool :=
      match
        (x,
          match x with
          | Stdlib.Ok n => OCaml.Stdlib.ge n 0
          | _ => false
          end) with
      | (Stdlib.Ok n, true) => true
      | (_, _) => false
      end.

We rename the existential type variables introduced by some constructors to their name in OCaml. The OCaml compiler typically names these variables `$something`. We can see the existential type names of OCaml in error messages or using [Merlin](https://github.com/ocaml/merlin) to inspect the type of an expression. Even if not necessary in most cases, having this renaming is helpful:

* in case some sub-expressions in a `match` branch cite the existential types in type annotations;
* for debugging, so that the type names on the Coq side are the same as on the OCaml side.

We do this renaming by doing a trick consisting into:

* building an `existT` value;
* destructuring this value right after, giving a name to the existential types at this moment.

For example, with our previous `printable` type example:

    type printable =
      | Printable : 'a * ('a -> string) -> printable

    let pretty_print (x : printable) : string =
      let Printable (v, to_string) = x in
      to_string v

we get:

    Inductive printable : Set :=
    | Printable : forall {a : Set}, a -> (a -> string) -> printable.

    Definition pretty_print (x : printable) : string :=
      let 'Printable v to_string := x in
      let 'existT _ __Printable_'a [v, to_string] :=
        existT (A := Set)
          (fun __Printable_'a => [__Printable_'a ** __Printable_'a -> string]) _
          [v, to_string] in
      to_string v.

because in OCaml the existential type is named `$Printable_'a` in this case (we replace the `$` symbol by `__` to get accepted by Coq).

## Pattern matching with axioms
Sometimes, doing a syntactic transformation for the pattern matching is not enough in case of GADTs. For example:

    type _ expr =
      | Int : int -> int expr
      | Couple : 'a expr * 'b expr -> ('a * 'b) expr

    let left_and_right (e : (int * 'a) expr) : int * 'a expr =
      match e with
      | Couple (Int n, e) -> (n, e)

generates:

    Inductive expr : Set :=
    | Int : int -> expr
    | Couple : expr -> expr -> expr.

    Definition left_and_right (e : expr) : int * expr :=
      let 'Couple (Int n) e := e in
      (n, e).

which is ill-typed in Coq:

    Error: Non exhaustive pattern-matching: no clause found for pattern Int _

### Default branch
We can require a default `match` branch with the OCaml attribute `@coq_match_with_default`:

    let left_and_right (e : (int * 'a) expr) : int * 'a expr =
      match[@coq_match_with_default] e with
      | Couple (Int n, e) -> (n, e)

which generates:

    Definition left_and_right (e : expr) : int * expr :=
      match e with
      | Couple (Int n) e => (n, e)
      | _ => unreachable_gadt_branch
      end.

where `unreachable_gadt_branch` is an axiom:

    Parameter unreachable_gadt_branch : forall {A : Set}, A.

### Casting at the entry of branches
Sometimes we need to cast the free variables introduced by patterns:

    type 'a int_or_bool =
      | Int : int int_or_bool
      | Bool : bool int_or_bool

    let to_int (type a) (kind : a int_or_bool) (x : a) : int =
      match[@coq_match_gadt] (kind, x) with
      | (Int, (x : int)) -> x
      | (Bool, (x : bool)) -> if x then 1 else 0

generates:

    Inductive int_or_bool : Set :=
    | Int : int_or_bool
    | Bool : int_or_bool.

    Definition to_int {a : Set} (kind : int_or_bool) (x : a) : Z :=
      match (kind, x) with
      | (Int, _ as x) =>
        let x := cast Z x in
        x
      | (Bool, _ as x) =>
        let x := cast bool x in
        if x then
          1
        else
          0
      end.

where we cast each pattern variable as explicitly stated in the OCaml code. Without type annotations the cast would be towards the type `a`, what is correct but unhelpful to type-check the Coq code. The `cast` operator is an axiom:

    Axiom cast : forall {A : Set} (B : Set), A -> B.

Note that this axiom is unsound as we can inhabit&nbsp;`Empty_set`:

    cast Empty_set tt : Empty_set

We suppose the use of the&nbsp;`cast` to be valid as we follow the types computed by the OCaml compiler. To eliminate the&nbsp;`cast` axiom is proofs, we can use the following evaluation axiom:

    Axiom cast_eval : forall {A : Set} {x : A}, cast A x = x.

For example, to show that&nbsp;`to_int` is idempotent over integers:

    Lemma to_int_idempotent (n : Z) : to_int Int (to_int Int n) = n.

we first evaluate the left-hand side expression:

    unfold to_int; simpl.

what gives us:

      n : Z
      ============================
      cast Z (cast Z n) = n
    1 subgoal

By rewriting two times with&nbsp;`cast_eval`:

    do 2 rewrite cast_eval.

we obtain:

    1 subgoal
      
      n : Z
      ============================
      n = n

and then by reflexivity the proof is completed. If we give incorrect parameters to&nbsp;`to_int`, such as:

    to_int Int false

the&nbsp;`cast_eval` axiom does not apply. Still, this term cannot be a valid OCaml code, so we believe that the&nbsp;`cast_eval` axiom covers all the interesting cases.

### Casting the result of branches
In case there is a need to also cast the result value of each branch there is the `@coq_match_gadt_with_result` attribute:

    let incr_if_int (type a) (kind : a int_or_bool) (x : a) : a =
      match[@coq_match_gadt_with_result] (kind, x) with
      | (Int, (x : int)) -> x + 1
      | (Bool, (x : bool)) -> x

generates:

    Definition incr_if_int {a : Set} (kind : int_or_bool) (x : a) : a :=
      match (kind, x) with
      | (Int, _ as x) =>
        let x := cast Z x in
        cast a (Z.add x 1)
      | (Bool, _ as x) =>
        let x := cast bool x in
        cast a x
      end.

### Casting with existential variables
When there are existential type variables in GADTs, we introduce them with an extended form of cast axiom:

    Axiom cast_exists : forall {A : Set} {Es : Type} (T : Es -> Set),
      A -> {vs : Es & T vs}.

where `Es` is typically a tuple of types. For example, to sum a tree of integers with some type witness, we transform:

    type _ ty =
      | Int : int ty
      | Couple : 'a ty * 'b ty -> ('a * 'b) ty

    let[@coq_struct "t"] rec sum : type a. a ty -> a -> int
      = fun t e ->
      match[@coq_match_gadt] (t, e) with
      | (Int, (n : int)) -> n
      | (Couple (t1, t2), (e1e2 : _ * _)) ->
        let (e1, e2) = e1e2 in
        sum t1 e1 + sum t2 e2

to:

    Unset Guard Checking. (* needed to disable termination check *)

    Inductive ty : Set :=
    | Int : ty
    | Couple : ty -> ty -> ty.

    Fixpoint sum {a : Set} (t : ty) (e : a) {struct t} : int :=
      match (t, e) with
      | (Int, _ as n) =>
        let n := cast int n in
        n
      | (Couple t1 t2, _ as e1e2) =>
        let 'existT _ [__0, __1] [t1, t2, e1e2] :=
          cast_exists (Es := [Set ** Set])
            (fun '[__0, __1] => [ty ** ty ** __0 * __1]) [t1, t2, e1e2] in
        let '(e1, e2) := e1e2 in
        Z.add (sum t1 e1) (sum t2 e2)
      end.


Here we need to introduce the existential variables with the cast to be able to say that `e1e2` is a couple of type `__1 * __2`, for _some_ types `__1` and `__2`. Like for pattern matching without GADTs, we reuse the names generated by OCaml, replacing the `$` symbol by `__`.

As a result, with all the techniques above, we can translate the whole Tezos protocol to Coq. This includes the interpreter and type-checker of the smart-contract language [Michelson](https://tezos.gitlab.io/whitedoc/michelson.html), which relies heavily on GADTs. We needed to annotate some of the functions manipulating GADTs, even if we tried to reduce the amount of annotations to a minimum. Eventually, we would like a system where we keep all the type information during the translation, so that we do not need axioms in the generated code.
