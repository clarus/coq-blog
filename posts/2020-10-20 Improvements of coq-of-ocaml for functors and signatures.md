With [coq-of-ocaml](https://clarus.github.io/coq-of-ocaml/) we can translate many [OCaml](https://ocaml.org/) constructs to an equivalent in the [Coq](https://coq.inria.fr/) language. Based on the code which we encounter, we continue to update coq-of-ocaml to handle more OCaml programming patterns. In this post, we will show:

* how we changed the representation of functors to have a clearer generated code;
* how we handled the anonymous sub-signatures.

> We develop [coq-of-ocaml]((https://clarus.github.io/coq-of-ocaml/)) at [🐙&nbsp;Nomadic&nbsp;Labs](https://www.nomadic-labs.com/) with the aim to formally verify OCaml programs, and in particular the implementation of the crypto-currency [Tezos](https://tezos.com/). If you want to use this tool for your own projects, please do not hesitate to look at our [website](https://clarus.github.io/coq-of-ocaml/) or [contact us](mailto:contact@nomadic-labs.com)!

## Functors like plain modules
Th module system of OCaml allows to represent modules parametrized by others. Such parametrized modules are called [functors](https://ocaml.org/releases/4.11/htmlman/moduleexamples.html#s:functors). We represent modules with a named signature by [records](https://coq.inria.fr/refman/language/core/records.html) in Coq. Then we encode functors by functions over dependent records. We like this representation because:

* we can also encode [first-class modules](https://ocaml.org/releases/4.11/htmlman/firstclassmodules.html) (modules used in the context of values in OCaml);
* it does not depend on the functor system of Coq, but only on dependent types. The less Coq features from the kernel we use, the safer we feel.

An issue we had was expressing lemmas about items of a functor. For example, with the following OCaml code:

    module type Source = sig
      type t
      val x : t
      val id : 'a -> 'a
    end

    module type Target = sig
      type t
      val y : t
    end

    module F (X : Source) : Target with type t = X.t = struct
      type t = X.t
      let y = X.x
    end

we would generate the following Coq code:

    Module Source.
      Record signature {t : Set} : Set := {
        t := t;
        x : t;
      }.
    End Source.

    Module Target.
      Record signature {t : Set} : Set := {
        t := t;
        y : t;
      }.
    End Target.

    Definition F :=
      fun (X : {t : Set & Source.signature (t := t)}) =>
        ((let t : Set := (|X|).(Source.t) in
        let y := (|X|).(Source.x) in
        existT (A := unit) (fun _ => _) tt
          {|
            Target.y := y
          |}) : {_ : unit & Target.signature (t := (|X|).(Source.t))}).

There are two module types `Source` and `Target` which we represent by record definitions. We parametrize these records by their abstract types. We represent the functor `F` by a function from the type of record `Source` to the type of record `Target`. Here the whole definition of `F` is packed into a single function. We define the resulting record using local `let` declarations. We changed that to have top-level definitions for each item of the functor (`t` and `y`). By representing the functor parameters as a type-class, we now generate:

    Module F.
      Class FArgs := {
        X : {t : Set & Source.signature (t := t)};
      }.
      
      Definition t `{FArgs} : Set := (|X|).(Source.t).
      
      Definition y `{FArgs} : (|X|).(Source.t) := (|X|).(Source.x).
      
      Definition functor `(FArgs)
        : {_ : unit & Target.signature (t := (|X|).(Source.t))} :=
        existT (A := unit) (fun _ => _) tt
          {|
            Target.y := y
          |}.
    End F.
    Definition F X := F.functor {| F.X := X |}.

The class `FArgs` contains the functor arguments. This class has one field per functor parameter (in this case only `X`). We give to each declaration an implicit parameter `` `{FArgs}`` so that the parameter `X` is always accessible. At the end of the module, we materialize the functor as a function `functor` from an instance of the class of parameters, to the record of the resulting module. Eventually, we define the functor `F` as a function taking parameters in order and convert them to an instance of the class `FArgs`.

Remark: we do not use the [section mechanism](https://coq.inria.fr/refman/language/core/sections.html), because this would not compose. Indeed, we cannot create modules inside sections in the current version of Coq. Thus we can only represent flat functors with sections, and cannot represent functors with sub-modules.

For modules represented by records we do the same, without the `FArgs` parameter. For example, we translate:

    module M : Source = struct
      type t = int
      let x = 12
      let id x = x
    end

to:

    Module M.
      Definition t : Set := int.
      
      Definition x : int := 12.
      
      Definition id {A : Set} (x : A) : A := x.
      
      Definition module :=
        existT (A := Set) _ t
          {|
            Source.x := x;
            Source.id _ := id
          |}.
    End M.
    Definition M := M.module.

We hope that this presentation is cleaner on the Coq side. For example:

* we can directly talk about individual items without referencing the whole resulting record;
* we can talk about intermediate items which may not be exported at the end;
* we can have plain sub-modules for large functors (which cannot be represented as records with the current system when there are no named signatures);
* we can define new types as we would at top-level.

## Anonymous sub-signatures
For large signatures, we tend to use sub-signatures in order to group items going together. For example, we can define in OCaml:

    module type T_encoding = sig
      type t

      val encoding : t list
    end

    module type Validator = sig
      module Ciphertext : sig
        include T_encoding

        val get_memo_size : t -> int
      end

      module CV : T_encoding

      type t = Ciphertext.t
    end

Since we represent signatures by records, we cannot directly represent the sub-signature for `Ciphertext` in the signature `Validator`. Indeed, there are no notions of sub-records in Coq. Thus, we were generating the following error message:

    --- foo.ml:8:23 ------------------------------------------------------------ not_supported (1/1) ---

       6 | 
       7 | module type Validator = sig
    >  8 |   module Ciphertext : sig
    >  9 |     include T_encoding
    > 10 | 
    > 11 |     val get_memo_size : t -> int
    > 12 |   end
      13 | 
      14 |   module CV : T_encoding
      15 | 


    Anonymous definition of signatures is not handled

Now we inline the sub-modules by prefixing the name of their fields, so that we generate a single flat record in Coq. For the OCaml code above, we generate:

    Module T_encoding.
      Record signature {t : Set} : Set := {
        t := t;
        encoding : list t;
      }.
    End T_encoding.

    Module Validator.
      Record signature {Ciphertext_t CV_t : Set} : Set := {
        Ciphertext_t := Ciphertext_t;
        Ciphertext_encoding : list Ciphertext_t;
        Ciphertext_get_memo_size : Ciphertext_t -> int;
        CV : T_encoding.signature (t := CV_t);
        t := Ciphertext_t;
      }.
    End Validator.

We prefix all the fields of the sub-module `Ciphertext` by `Ciphertext_`. We propagate the naming of the types. For example the type `t` from `Ciphertext` is renamed as `Ciphertext_t` in all the subsequent expressions. For all other fields which involve this type `t`, we mark it as `Ciphertext_t`. We keep using nested records for sub-signatures with a name. For example, the sub-module `CV` is a field of type `T_encoding.signature`, which is itself a record. The two variables `Ciphertext_t` and `CV_t` are the two abstract types of the signature. As with flat signatures, we represent them using existential types when unknown.

We also changed the way we translate the identifiers to reference items in signatures. For example, if we have a functor using the field `Ciphertext.get_memo_size`:

    module F (V : Validator) = struct
      let get = V.Ciphertext.get_memo_size
    end

we now generate:

    Module F.
      Class FArgs := {
        V :
          {'[Ciphertext_t, CV_t] : [Set ** Set] &
            Validator.signature (Ciphertext_t := Ciphertext_t) (CV_t := CV_t)};
      }.
      
      Definition get `{FArgs} : (|V|).(Validator.Ciphertext_t) -> int :=
        (|V|).(Validator.Ciphertext_get_memo_size).
    End F.

Here we represent `V.Ciphertext.get_memo_size` by `(|V|).(Validator.Ciphertext_get_memo_size)`. We use the notation to access record fields with `record.(field)`. We project the potential existential variables with the notation `(|...|)`. Here are the steps we followed to translate this identifier:

* check if `V` has a known named signature (in this case we find the signature `Validator`);
* check if `Ciphertext` has a known signature (we do not find one);
* conclude that the `get_memo_size` field has probably been inlined in the signature definition;
* generate a record access on `V` on the field `Ciphertext_get_memo_size`, which is the concatenation of `Ciphertext` and `get_memo_size` according to the way we prefix field names in inlining.

The handling of anonymous sub-signatures is not completely mandatory. Indeed, we could also give a name to the sub-signatures in the OCaml code. However we encountered some cases were this was convenient, in order not to modify the OCaml code too much.

## Conclusion
We have shown two new translation strategies which, we hope, will polish the experience of using [coq-of-ocaml](https://github.com/clarus/coq-of-ocaml). This work was mainly directed by an experiment at handling some code from the [Tezos](https://tezos.com/) codebase. The aim was to verify some parts of the [sapling](https://blog.nomadic-labs.com/sapling-integration-in-tezos-tech-preview.html) project. This code is outside of the protocol, which is the part we are the most used to work with. Then, we met some new OCaml constructs and patterns. In particular, we encountered large functors with anonymous sub-signatures, plain sub-modules, and new type definitions.
