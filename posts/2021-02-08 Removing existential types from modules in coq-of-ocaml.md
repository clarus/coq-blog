The tool [coq-of-ocaml](https://github.com/clarus/coq-of-ocaml) translates [OCaml](https://ocaml.org/) programs to [Coq](https://coq.inria.fr/) programs using a shallow embedding. To translate the [modules and functors](https://caml.inria.fr/pub/docs/manual-ocaml/moduleexamples.html) of OCaml we use polymorphic [records](https://coq.inria.fr/refman/language/core/records.html) in Coq. With this representation, we are also able to translate [first-class modules](https://caml.inria.fr/pub/docs/manual-ocaml/firstclassmodules.html).

We originally used existential types to represent abstract module types. This could be a source of complexity for the reasoning on the generated code. Indeed, existential types require to do frequent [projections](https://coq.inria.fr/library/Coq.Init.Specif.html#projT2) and [wrapping](https://coq.inria.fr/library/Coq.Init.Specif.html#existT) in Coq. In this blog post, we show how we removed the need of existential types in most non-first-class modules.

> We develop [coq-of-ocaml]((https://clarus.github.io/coq-of-ocaml/)) at [🐙 Nomadic Labs](https://www.nomadic-labs.com/) with the aim to formally verify OCaml programs, and in particular the implementation of the crypto-currency [Tezos](https://tezos.com/). If you want to use this tool for your own projects, please do not hesitate to look at our [website](https://clarus.github.io/coq-of-ocaml/) or [contact us](mailto:contact@nomadic-labs.com)!

## Example
We take the following OCaml code:

    module F (X : Source) : Target with type t2 = X.t = struct
      type t1 = string
      type t2 = X.t
      let y = X.x
    end

    module FM = F (M)

We assume that:

* the signature `Source` has one abstract type `t`;
* the signature `Target` has two abstract types `t1` and `t2`, the type `t2` being explicitly specified as `X.t` in this example.

### Now
We show how we now translate this OCaml example with the latest changes in coq-of-ocaml. In particular, we show how we avoid using existential types for the abstract module types. We start by using a [Coq type class](https://coq.inria.fr/refman/addendum/type-classes.html) to represent the functor parameters as explained in a [previous article](http://coq-blog.clarus.me/improvements-of-coq-of-ocaml-for-functors-and-signatures.html):

    Module F.
      Class FArgs {X_t : Set} := {
        X : Source (t := X_t);
      }.
      Arguments Build_FArgs {_}.

We represent the abstract type `t` of `X` with a parameter `X_t` of the class `FArgs`. This type is implicit (notation&nbsp;`{}`) since we can infer it from the module `X`. We then define the various fields of the functor, including a special field&nbsp;`functor` which is the record representing the result of the functor:

      Definition t1 `{FArgs} : Set := string.
      
      Definition t2 `{FArgs} : Set := X.(Source.t).
      
      Definition y `{FArgs} : X.(Source.t) := X.(Source.x).
      
      Definition functor `{FArgs} :=
        {|
          Target.y := y
        |}.
    End F.

Finally, we wrap the functor `F.functor` into a function `F` without type classes:

    Definition F {X_t : Set} (X : Source (t := X_t))
      : Target (t1 := _) (t2 := X.(Source.t)) :=
      let '_ := F.Build_FArgs X in
      F.functor.

We keep `X_t` as an implicit parameter. The type `X_t` is a parameter rather than an existential type. For the abstract type `t1`, we let Coq infer its value with:

    Target (t1 := _) (t2 := X.(Source.t))

Since Coq has access to the definition of&nbsp;`F`, it is able to guess the value of `t1`, and we do not need an existential type there. For the type `t2`, we directly give its value&nbsp;`X.(Source.t)` like in the OCaml source. We think it is better to always give an explicit type value when possible. Indeed, the expression inferred by Coq may be too large and have caused performance issues in some of our examples.

To apply the functor&nbsp;`F` on&nbsp;`M` we simply do a function application:

    Definition FM := F M.

Coq infers all the missing abstract type values for us.

### Before
Before these recent changes, we were wrapping all the modules into one existential type for each abstract type. On this example, we would have generated the following Coq code:

    Module F.
      Class FArgs := {
        X : {t : Set & Source.signature (t := t)};
      }.
      
      Definition t1 `{FArgs} : Set := string.
      
      Definition t2 `{FArgs} : Set := (|X|).(Source.t).
      
      Definition y `{FArgs} : (|X|).(Source.t) := (|X|).(Source.x).
      
      Definition functor `(FArgs)
        : {t1 : Set & Target.signature (t1 := t1) (t2 := (|X|).(Source.t))} :=
        existT (A := Set) _ t1
          {|
            Target.y := y
          |}.
    End F.
    Definition F X := F.functor {| F.X := X |}.

    Definition FM := F (existT (A := Set) _ _ (|M|)).

We wrap the abstract type `t` of `X` in the existential:

    {t : Set & Source.signature (t := t)}

We wrap the abstract type `t1` in the existential:

    existT (A := Set) _ t1 {| ... |}

To access the fields of each module we first project the existential types with the notation:

    Notation "(| M |)" := (projT2 M).

To apply the functor&nbsp;`F` to&nbsp;`M` we also wrap `M` into an existential in order to be sure to have the correct number of existential types. We believe that the use of existential types associated with frequent projections or wrapping was a source of complexity for proofs made on the generated Coq code.

## Strategy
We now describe the general strategy we use to remove the need of existential types in common use cases.

### Definitions
When we define a module&nbsp;`M` with some abstract types in the signature, we let Coq infer their values. When we define a functor&nbsp;`F` parametrized by some modules:

    M_1, ..., M_n

with the abstract types:

    M_1 : t_1_1, t_1_2, ...
    ...
    M_n : t_n_1, t_n_2, ...

and returning a module of signature&nbsp;`S` with the abstract types:

    S : t_1, t_2, ...

we push all the abstract types in front, so that the type of the function representing the functor `F` in Coq is:

    F :
      (* The abstract types could also have a higher arity such as Set -> Set *)
      forall {t_1_1 t_1_2 ... t_n_1 t_n_2 ... : Set},
      forall (M1 : M_1_signature (t_1_1 := t_1_1) (t_1_2 := t_1_2) ...),
      ...
      forall (M_n : M_n_signature (t_n_1 := t_n_1) (t_n_2 := t_n_2) ...),
      S
        (t_1 := either _ if abstract or some type expression if specified)
        ...
        (t_n := ...)

We only support functors whose parameters are all modules. Since we support modules containing functors, it is possible to wrap a functor into a module to pass it to another functor. However the functors in modules cannot return some abstract types (we had [universe level](http://adam.chlipala.net/cpdt/html/Universes.html) issues with that). We also expect the functors to be applied on all their parameters at once (no [currying](https://en.wikipedia.org/wiki/Currying)). Indeed, we need to infer all the abstract types of the parameters at once.

An example of a functor type from the [Coq code generated from Tezos](https://gitlab.com/nomadic-labs/coq-tezos-of-ocaml) is the following:

    Definition Make_single_data_storage {C_t V_t : Set}
      (R : Storage_sigs.REGISTER) (C : Raw_context.T (t := C_t))
      (N : Storage_sigs.NAME) (V : Storage_sigs.VALUE (t := V_t))
      : Storage_sigs.Single_data_storage (t := C.(Raw_context.T.t))
        (value := V.(Storage_sigs.VALUE.t)) :=
      (* ... the definition *)

### Axioms
We convert&nbsp;`.mli` files to lists of axioms. This raises an issue as we cannot infer the abstract types in a module or in the output module of a functor anymore. This inference is not possible because we do not have access to the definition of axioms. We solve this issue by adding one more axiom for each type to infer.

For example, in OCaml the module&nbsp;[`Map`](https://caml.inria.fr/pub/docs/manual-ocaml/libref/Map.html) is declared as follows:

    module type S = sig
      (** The type of the map keys. *)
      type key

      (** The type of maps from type [key] to type ['a]. *)
      type +'a t

      (* ... *)
    end

    module Make: functor (Ord : OrderedType) -> S with type key = Ord.t

The signature&nbsp;`S` has two abstract types&nbsp;`key` and&nbsp;`t`. The signature&nbsp;`OrderedType` has one abstract type&nbsp;`t`. We transform the declaration of the functor&nbsp;`Make` to the axioms:

    Parameter Make_t :
      forall {Ord_t : Set} (Ord : OrderedType (t := Ord_t)), Set -> Set.

    Parameter Make :
      forall {Ord_t : Set},
      forall (Ord : OrderedType (t := Ord_t)),
      S (key := Ord.(OrderedType.t)) (t := Make_t Ord).

Since the abstract type&nbsp;`t` of the signature&nbsp;`S` is unspecified, we introduce an additional axiom&nbsp;`Make_t` to describe its value. This axiom takes the same arguments as the functor&nbsp;`Make`.

### First-class modules
We keep using existential types for the [first-class modules](https://caml.inria.fr/pub/docs/manual-ocaml/firstclassmodules.html). This is because first-class module values can appear at any position in a program (in a function, in a data structure, ...). Thus the methods above would not be enough to eliminate the need of existential types in all cases.

We use the following strategy:

* we add the existential types when we go from a module to a value;
* we remove the existential types (by projection) when we go from a value to a module;
* when we access to the field of a first-class module, we consider that the existential types have already been removed, since it has already been converted to a module.

Here is an example of OCaml code with first-class modules, from the code of Tezos:

    type ('key, 'value) map =
      (module Boxed_map with type key = 'key and type value = 'value)

    let map_set : type a b. a -> b -> (a, b) map -> (a, b) map =
    fun k v (module Box) ->
      ( module struct
        type key = a

        type value = b

        let key_ty = Box.key_ty

        module OPS = Box.OPS

        let boxed =
          let (map, size) = Box.boxed in
          (Box.OPS.add k v map, if Box.OPS.mem k map then size else size + 1)
      end )

This implements a map type which is polymorphic in the type of the keys. One needs to give the comparison function for the keys when initializing an empty map. We translate this code to:

    Definition map (key value : Set) : Set :=
      {OPS_t : Set -> Set @
        Boxed_map (key := key) (value := value) (OPS_t := OPS_t)}.

    Definition map_set {a b : Set} (k : a) (v : b) (Box : map a b)
      : map a b :=
      let 'existS _ _ Box := Box in
      existS (A := Set -> Set) _ _
        (let key : Set := a in
        let value : Set := b in
        let key_ty := Box.(Boxed_map.key_ty) in
        let OPS := Box.(Boxed_map.OPS) in
        let boxed :=
          let '(map, size) := Box.(Boxed_map.boxed) in
          ((Box.(Boxed_map.OPS).(S.MAP.add) k v map),
            (if Box.(Boxed_map.OPS).(S.MAP.mem) k map then
              size
            else
              size +i 1)) in
        {|
          Boxed_map.key_ty := key_ty;
          Boxed_map.OPS := OPS;
          Boxed_map.boxed := boxed
        |}).

We use an existential type to define the type&nbsp;`map`. Note that we use an existential type in the sort&nbsp;`Set` with the [imprediative Set](https://github.com/coq/coq/wiki/Impredicative-Set) option of Coq enabled. This allows us to avoid any universe level issue by always staying in the sort&nbsp;`Set`. We define the existential in&nbsp;`Set` like the ones in&nbsp;`Prop` or&nbsp;`Type`:

    Inductive sigS (A : Type) (P : A -> Set) : Set :=
    | existS : forall (x : A), P x -> sigS P.

    Notation "{ x : A @ P }" := (sigS (A := A) (fun x => P)) : type_scope.

To open the first-class module value&nbsp;`Box` as a module we use the pattern:

    fun k v (module Box) ->

in OCaml. We convert this pattern to an existential projection:

    let 'existS _ _ Box := Box in

in Coq. Then to close the module and convert it back to a value, we wrap it into an existential with:

    existS (A := Set -> Set) _ _ (...)

## Conclusion
We hope that the effort we made into removing existential types from the generated Coq code will help to do simpler proofs on OCaml programs using a lot of modules.
