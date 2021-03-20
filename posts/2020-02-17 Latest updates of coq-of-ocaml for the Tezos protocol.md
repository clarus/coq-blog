We recently made a lot of progress on the formalization in [Coq](https://coq.inria.fr/) of the [Tezos economic protocol](https://gitlab.com/tezos/tezos/-/tree/master/src/proto_alpha/lib_protocol), written in [OCaml](https://ocaml.org/), using [coq-of-ocaml](https://clarus.github.io/coq-of-ocaml/). We present here some of the new features of coq-of-ocaml and the results on the formalization of Tezos.

> We develop [coq-of-ocaml]((https://clarus.github.io/coq-of-ocaml/)) at [🐙 Nomadic Labs](https://www.nomadic-labs.com/) with the aim to formally verify OCaml programs, and in particular the implementation of the crypto-currency [Tezos](https://tezos.com/). If you want to use this tool for your own projects, please do not hesitate to look at our [website](https://clarus.github.io/coq-of-ocaml/) or [contact us](mailto:contact@nomadic-labs.com)!

## Functors
Previously, we were using dependent records to represent first-class modules. We now use dependent records whenever possible, even for non-first-class modules. This enables us to convert [OCaml functors](https://dev.realworldocaml.org/functors.html) to Coq functions over dependent records. As an example, we translate this OCaml program:

    (* Signature of the parameter of the functor *)
    module type Source = sig
      type t
      val x : t
    end

    (* Signature of the result of the functor *)
    module type Target = sig
      type t
      val y : t
    end

    (* Definition of the functor *)
    module F (X : Source) : Target with type t = X.t = struct
      type t = X.t
      let y = X.x
    end

    (* Application to the module [M] *)
    module M : Source = struct
      type t = int
      let x = 12
    end

    module N = F (M)

to the following Coq code:

    Module Source.
      Record signature {t : Set} := {
        t := t;
        x : t;
      }.
      Arguments signature : clear implicits.
    End Source.

    Module Target.
      Record signature {t : Set} := {
        t := t;
        y : t;
      }.
      Arguments signature : clear implicits.
    End Target.

    Definition F :=
      fun (X : {t : _ & Source.signature t}) =>
        (let t := (|X|).(Source.t) in
        let y := (|X|).(Source.x) in
        existT (fun _ => _) tt
          {|
            Target.y := y
          |} : {_ : unit & Target.signature (|X|).(Source.t)}).

    Definition M :=
      let t := Z in
      let x := 12 in
      existT _ _
        {|
          Source.x := x
        |}.

    Definition N :=
      F
        (existT _ _
          {|
            Source.x := (|M|).(Source.x)
          |}).

We note `(|M|)` the projection `projT2` to get the second component of an existential type `{x : A & P x}`. We represent signatures by records parametrized by their abstract types. We wrap these records with existential types for the abstract types which are not precised by a `with type t = ...` construct. Functors are then plain Coq functions over dependent records. For more details, see the documentation on the [module system](https://clarus.github.io/coq-of-ocaml/docs/module-system) in coq-of-ocaml.

Our convention is to represent a module as a dependent record if there exists a name for its signature. In this case, we use its signature name for its record's type name. We consider the other modules as namespaces, and represent them with standard Coq modules.

## GADTs and existential types
[GADTs](https://caml.inria.fr/pub/docs/manual-ocaml/manual033.html), an advanced form of algebraic datatypes, are used a lot in the Tezos protocol. They help to ensure safety properties, like the soundness of the type-checker of the smart-contracts.

### GADTs
As we did not find a general way to convert GADTs to Coq, we chose to erase the type annotations and introduce unsafe casts. Here is an example of OCaml code with a GADT:

    type 'a int_or_string =
      | Int : int int_or_string
      | String : string int_or_string

    let to_string (type a) (kind : a int_or_string) (x : a) : string =
      match[@coq_match_gadt] kind, x with
      | Int, (x : int) -> string_of_int x
      | String, (x : string) -> x

Note the `[@coq_match_gadt]` on the `match` and the type annotations on the variable `x` in the patterns. We import this code in Coq to:

    Reserved Notation "'int_or_string".

    Inductive int_or_string_gadt : Set :=
    | Int : int_or_string_gadt
    | String : int_or_string_gadt

    where "'int_or_string" := (fun (_ : Set) => int_or_string_gadt).

    Definition int_or_string := 'int_or_string.

    Definition to_string {A : Set} (kind : int_or_string A) (x : A) : string :=
      match (kind, x) with
      | (Int, _ as x) =>
        let 'existT _ tt x := cast_exists (fun _ => Z) x in
        cast string (OCaml.Stdlib.string_of_int x)
      | (String, _ as x) =>
        let 'existT _ tt x := cast_exists (fun _ => string) x in
        cast string x
      end.

We convert the GADT `int_or_string` to an inductive `int_or_string_gadt` without annotations. We generate two axioms in each branch of the `match`, to cast:

* the variables introduced by the pattern;
* the result of the branch.

The axiom `cast` is the equivalent in Coq of the OCaml's [Obj.magic](https://caml.inria.fr/pub/docs/manual-ocaml/libref/Obj.html) cast. It has the following signature:

    Axiom cast : forall {A : Set} (B : Set), A -> B.

We say that:

* `cast` behaves as the identity function when `A` is equal to `B`;
* is undefined in other cases.

To specify this behavior, we use the following axiom:

    Axiom cast_eval : forall {A : Set} {x : A}, cast A x = x.

While doing proofs, we must use the axiom `cast_eval` to evaluate `cast` by proving that the types `A` and `B` are the same. Doing so, we also verify that the type unifications of the type-checker of OCaml are indeed correct. The `cast_exists` axiom is like `cast` with the ability to introduce some existential variables when needed.

### Existential variables
Types with existential variables are a special case of GADTs, where the type parameters are the same for all the constructors. For example, to represent a value which can be converted to a `string`, we can use:

    type printable = Printable : 'a * ('a -> string) -> printable

    let printable_to_string (x : printable) : string =
      let Printable (value, print) = x in
      print value

In this example, `'a` is an existential variable. Coq also support existential variables in algebraic types. Here is what we generate for this example:

    Inductive printable : Set :=
    | Printable : forall {a : Set}, a -> (a -> string) -> printable.

    Definition printable_to_string (x : printable) : string :=
      let 'Printable value print := x in
      let 'existT _ __Printable_'a [value, print] :=
        existT
          (fun __Printable_'a : Set =>
            [__Printable_'a ** (__Printable_'a -> string)]) _ [value, print] in
      print value.

We do not need any axioms. The `let 'existT _ __Printable_'a [value, print] :=` block is there to rename the existential variables generated by Coq to the names of the OCaml compiler. We replace the forbidden symbol `$` by `__`, so that:

    $Printable_'a

becomes:

    __Printable_'a

Having well named existential variables helps to get:

* cleaner error messages;
* type annotations on sub-expressions using these existential variables.

## Documentation website
We added a [website for coq-of-ocaml](https://clarus.github.io/coq-of-ocaml/) to have a central place with documentation. We used [Docusaurus](https://docusaurus.io/) to generate the website. We chose Docusaurus for the following reasons:

* open-source;
* good defaults;
* generates static HTML;
* we can write the documentation in Markdown.

## We converted most of the protocol
At the time of writing, 57% of the Coq code generated by coq-of-ocaml for the Tezos protocol compiles. This includes the interpreter of the smart-contracts, and amounts to around 30.000 lines of valid Coq code. We still ignore many features, like the side-effects or the extensible types. The main missing files are the `*_services.ml` files and the type-checker of smart-contracts (6.000 lines of OCaml, the largest file of the protocol).
