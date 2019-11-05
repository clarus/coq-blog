For now, [coq-of-ocaml](https://github.com/clarus/coq-of-ocaml) only supports plain modules used as namespaces (no functors). [First-class modules](https://caml.inria.fr/pub/docs/manual-ocaml/manual028.html) are an important construction to abstract code in [OCaml](https://ocaml.org/) as there are flexible and used heavily in some programs (including in [Tezos](https://tezos.com/)). We present our strategy to import first-class modules to dependent record in [Coq](https://coq.inria.fr/). We show that it works for the set example extracted from the Tezos source code.

*This work was financed by [Nomadic Labs](https://www.nomadic-labs.com/) with the aim to verify the OCaml implementation of the&nbsp;[Tezos](https://tezos.com/) blockchain. [coq-of-ocaml](https://github.com/clarus/coq-of-ocaml) is a compiler from&nbsp;OCaml to&nbsp;Coq.*

## Strategy
Here is an example of a first-class module in OCaml. We say that a type&nbsp;`t` is&nbsp;`Printable` when it provides a function&nbsp;`to_string` to convert it in&nbsp;`string`:

    module type Printable = sig
      type t
      val to_string : t -> string
    end

Given a printable type, we can write a generic function to print it on the terminal:

    let print_on_the_terminal
      (type a)
      (module PrintableInstance : Printable with type t = a)
      (x : a)
      : unit =
      print_endline (PrintableInstance.to_string x)

The module&nbsp;`Printable` encapsulates both a type&nbsp;`t` and some associated data&nbsp;`to_string`. We model that with a dependent record in&nbsp;Coq, that is to say a record mixing types and values:

    Module Printable.
      Record signature {t : Type} := {
        t := t;
        to_string : t -> string;
      }.
      Arguments signature : clear implicits.
    End Printable.

Since the type&nbsp;`t` is not known at this point, we model it with a type parameter&nbsp;`t`. Later on, when someone uses the syntax&nbsp;`with type t = ...`, we call the&nbsp;`signature` with the value for&nbsp;`t`. We define a synony field &nbsp;`t := t` to have a uniform way to access to the fields of the module. We put the whole record into a module&nbsp;`Printable` to namespace the projections and prevent name collisions.

We generate the following Coq code for the&nbsp;`print_on_the_terminal` function:

    Definition print_on_the_terminal {A : Type}
      (PrintableInstance : {_ : unit & Printable.signature A}) : A -> unit :=
      let PrintableInstance := projT2 PrintableInstance in
      fun x =>
        print_endline (PrintableInstance.(Printable.to_string) x).

The&nbsp;`print_endline` function is an axiom, as side-effects are forbidden in&nbsp;Coq. The curly braces&nbsp;`{}` set implicit the type parameter&nbsp;`A`, because type variables are implicit in OCaml. The&nbsp;`PrintableInstance` value is a dependent pair, since it may contain a list of type values for the abstract types of the module. Here the only abstract type&nbsp;`t` is already filled with a value&nbsp;`A`, thus there are no type values&nbsp;(`_ : unit`). We open the dependent pair with&nbsp;`projT2`. We use the projection&nbsp;`Printable.to_string` to access to the&nbsp;`to_string` function of the module.

We often use types with a first-class module in a boxed form, where we associate both a module type and its value:

    module type BoxedPrintable = sig
      module Printable : Printable
      val value : Printable.t
    end

    let print_boxed_printable (module BoxedPrintable : BoxedPrintable) : unit =
      print_endline (BoxedPrintable.Printable.to_string BoxedPrintable.value)

In&nbsp;Coq, we proceed as for the previous module and propagate the abstract type&nbsp;`t` of the sub-module&nbsp;`Printable` to the signature of&nbsp;`BoxedPrintable`:

    Module BoxedPrintable.
      Record signature {Printable_t : Type} := {
        Printable : Printable.signature Printable_t;
        value : Printable.(Printable.t);
      }.
      Arguments signature : clear implicits.
    End BoxedPrintable.

For the function&nbsp;`print_boxed_printable`, we use a parameter&nbsp;`Printable_t` in the dependent pair&nbsp;`BoxedPrintable` as the abstract type&nbsp;`t` is not known at this point. More generally, the abstract types are universally quantified in the definition of signatures and existentially quantified in values.

    Definition print_boxed_printable
      (BoxedPrintable : {Printable_t : _ & BoxedPrintable.signature Printable_t})
      : unit :=
      let BoxedPrintable := projT2 BoxedPrintable in
      print_endline
        (BoxedPrintable.(BoxedPrintable.Printable).(Printable.to_string)
          BoxedPrintable.(BoxedPrintable.value)).

Note that the path to access to the&nbsp;`to_string` function is&nbsp;Coq is more verbose and more explicit than in&nbsp;OCaml.

## What we support
We support first-class modules with values, abstract types and type synonyms. We do not support first-class modules with other kind of fields, such as the definition of new algebraic data types. We do not support functors (although we support first-class functions on first-class modules).

A difficulty is to be able to distinguish between first-class modules and plain modules. This is necessary because we import first-class modules to dependent records and plain modules to&nbsp;Coq modules. For example, for projections, the syntax in&nbsp;OCaml is the same in both cases but different in&nbsp;Coq. When accessing a field of a module, we consider the module to be first-class if there exists a signature of the same shape. Once we found the name of the signature, we generate a call to the corresponding projection in&nbsp;Coq. If there are more than one signature corresponding to a module we generate an error. This can be the case because&nbsp;OCaml modules are not generative by default. The strategy to decide if a module is first-class is a heuristic, we may reconsider it latter.

## Set example
Here is the definition of sets as first-class modules, extracted from the&nbsp;[Tezos source code](https://gitlab.com/tezos/tezos/):

    module S = struct
      module type SET = sig
        type elt
        type t
        val empty: t
        val is_empty: t -> bool
        val mem: elt -> t -> bool
        val add: elt -> t -> t
        val remove: elt -> t -> t
      end
    end

    type 'a comparable_ty

    module type Boxed_set = sig
      type elt
      val elt_ty : elt comparable_ty
      module OPS : S.SET with type elt = elt
      val boxed : OPS.t
      val size : int
    end

    type 'elt set = (module Boxed_set with type elt = 'elt)

    let set_update
      : type a. a -> bool -> a set -> a set
      = fun v b (module Box) ->
      (module struct
        type elt = a
        let elt_ty = Box.elt_ty
        module OPS = Box.OPS
        let boxed =
          if b
          then Box.OPS.add v Box.boxed
          else Box.OPS.remove v Box.boxed
        let size =
          let mem = Box.OPS.mem v Box.boxed in
        if mem
        then if b then Box.size else Box.size - 1
        else if b then Box.size + 1 else Box.size
      end)

We successfully generate the following valid&nbsp;Coq code:

    Module S.
      Module SET.
        Record signature {elt t : Type} := {
          elt := elt;
          t := t;
          empty : t;
          is_empty : t -> bool;
          mem : elt -> t -> bool;
          add : elt -> t -> t;
          remove : elt -> t -> t;
        }.
        Arguments signature : clear implicits.
      End SET.
    End S.

    Parameter comparable_ty : forall (a : Type), Type.

    Module Boxed_set.
      Record signature {elt OPS_t : Type} := {
        elt := elt;
        elt_ty : comparable_ty elt;
        OPS : S.SET.signature elt OPS_t;
        boxed : OPS.(S.SET.t);
        size : Z;
      }.
      Arguments signature : clear implicits.
    End Boxed_set.

    Definition set (elt : Type) := {OPS_t : _ & Boxed_set.signature elt OPS_t}.

    Definition set_update {a : Type} (v : a) (b : bool) (Box : set a) : set a :=
      let Box := projT2 Box in
      existT _ _
        {|
          Boxed_set.elt_ty := Box.(Boxed_set.elt_ty);
          Boxed_set.OPS := Box.(Boxed_set.OPS);
          Boxed_set.boxed :=
            if b then
              Box.(Boxed_set.OPS).(S.SET.add) v Box.(Boxed_set.boxed)
            else
              Box.(Boxed_set.OPS).(S.SET.remove) v Box.(Boxed_set.boxed);
          Boxed_set.size :=
            let mem := Box.(Boxed_set.OPS).(S.SET.mem) v Box.(Boxed_set.boxed) in
            if mem then
              if b then
                Box.(Boxed_set.size)
              else
                Z.sub Box.(Boxed_set.size) 1
            else
              if b then
                Z.add Box.(Boxed_set.size) 1
              else
                Box.(Boxed_set.size)
          |}.

We use&nbsp;`existT _ _` to instantiate a dependent pair. We rely on the inference mechanism of&nbsp;Coq to fill the existential type variable&nbsp;`OPS_t` in this pair.

## Future work and opinions
Things are not perfect yet. We still need to test the implementation more, debug, and add some features such as polymorphic abstract types.

As a matter of taste, we prefer to import&nbsp;OCaml code to dependent records rather than functors. Indeed, we believe that records are safer than functors. The implementation of functors in the&nbsp;Coq kernel is complex as we have heard, while dependent records are already given by the dependent types. Moreover,&nbsp;Coq functors are generative while&nbsp;OCaml ones are not. We hope that we will not need&nbsp;Coq functors to import the code we wish to verify.
