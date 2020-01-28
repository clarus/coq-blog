The protocol of&nbsp;[Tezos](https://tezos.com/) is written in the&nbsp;[OCaml](https://ocaml.org/) language. It uses a&nbsp;[restricted&nbsp;OCaml interface](https://gitlab.com/tezos/tezos/tree/master/src/lib_protocol_environment/sigs/v1) of a few thousands lines of code to access to its primitives. Using the compiler&nbsp;[coq-of-ocaml](https://github.com/clarus/coq-of-ocaml), we generate a&nbsp;[Coq formalization of most of the&nbsp;Tezos protocol's interface](static/artifacts/tezos-interface-in-coq/v1_mli.html)&nbsp;(the missing&nbsp;OCaml constructs are listed&nbsp;[here](https://clarus.github.io/coq-of-ocaml/examples/tezos-interface/)). We hope this work to be a first step to enable formal reasoning on the implementation of the&nbsp;Tezos protocol. In this blog post, we present what we added to&nbsp;`coq-of-ocaml` in order to support the&nbsp;Tezos interface.

*This work was financed by&nbsp;[Nomadic&nbsp;Labs](https://www.nomadic-labs.com/) with the aim to verify the&nbsp;OCaml implementation of the&nbsp;Tezos blockchain. [coq-of-ocaml](https://github.com/clarus/coq-of-ocaml) is a compiler from&nbsp;OCaml to&nbsp;Coq.*

## Polymorphic variants
In&nbsp;OCaml, we can tag sum types with the backquote operator as follows:

    type json =
      [ `O of (string * json) list
      | `Bool of bool
      | `Float of float
      | `A of json list
      | `Null
      | `String of string ]

There are no direct equivalents in&nbsp;[Coq](https://coq.inria.fr/) and we generate a warning message when we encounter tags. Still, we generate some code as a first approximation. For type definitions we generate a&nbsp;Coq inductive:

    Inductive json : Set :=
    | Bool : bool -> json
    | Null : json
    | O : list (string * json) -> json
    | Float : Z -> json
    | String : string -> json
    | A : list json -> json.

and for inlined variants:

    val fold :
      t ->
      key ->
      init:'a ->
      f:([`Key of key | `Dir of key] -> 'a -> 'a Lwt.t) ->
      'a Lwt.t

we generate a sum type with the tags as comments:

    Parameter fold : forall {a : Set},
      t -> key -> a -> ((* `Dir *) key + (* `Key *) key -> a -> Lwt.t a) ->
      Lwt.t a.

## Types and values collisions
In&nbsp;Coq, in contrast to&nbsp;OCaml, types and values live in the same namespace. Thus there are often name collisions in the generated code. Typically, this is due to the use of values having the same name as their type. We prevent that for the common cases&nbsp;(`list`, `string`, ...) by translating the value names with a&nbsp;`_value` suffix. For example, we convert:

    val string : string encoding

to:

    Parameter __string_value : encoding string.

## Modules
We added the import of the definitions of module types in the&nbsp;`.mli` files. The code to do so is the same as for&nbsp;`.ml` files. For example, we import:

    module type COMPARABLE = sig
      type t

      val compare : t -> t -> int
    end

to:

    Module COMPARABLE.
      Record signature {t : Set} := {
        t := t;
        compare : t -> t -> Z;
      }.
      Arguments signature : clear implicits.
    End COMPARABLE.

We handle the import of modules declared with a signature by unfolding the signature. We do so as we do not represent signatures in&nbsp;Coq unless for first-class modules&nbsp;(using a record type). For example, we import:

    module String : COMPARABLE with type t = string

to:

    Module String.
      Definition t := string.
      
      Parameter compare : t -> t -> Z.
    End String.

This idea is due to&nbsp;[Mehdi Bouaziz](https://fr.linkedin.com/in/mehdibouaziz).

We also handle the&nbsp;`include` keyword by doing a similar unfolding. The unfolding of&nbsp;`include` significantly increases the size of the&nbsp;Coq code for the Tezos protocol's interface. Indeed, the number of generated lines for the interface was multiplied by two once we converted the&nbsp;`include` occurences.

## First-class modules
We improved the detection of first-class modules. The detection of first-class modules is a challenge in&nbsp;`coq-of-ocaml`. Indeed, we need to distinguish between first-class and plain modules in order to generated either a dependent record or a&nbsp;Coq module. Moreover, there are no builtin ways to translate between a record and a module in&nbsp;Coq.

When we access to the field of a module, we consider this module as a&nbsp;Coq record when it:

* has a named signature (to have a corresponding named record definition);
* is locally opened in an expression.

We added the constraint of being locally opened in order to filter out some plain modules with a named signature. We may change this rule in the future and convert more plain modules to records by default, as this could factorize the generated code and help to handle functors.

We added the support of first-class modules with polymorphic abstract types. For that, we mark the arity of the abstract types. For example, for a map signature in&nbsp;OCaml:

    module type MAP = sig
      type key
      type +'a t
      val empty : 'a t
      val is_empty : 'a t -> bool
      val mem : key -> 'a t -> bool
    end

we generate:

    Module MAP.
      Record signature {key : Set} {t : Set -> Set} := {
        key := key;
        t := t;
        empty : forall {a : Set}, t a;
        is_empty : forall {a : Set}, t a -> bool;
        mem : forall {a : Set}, key -> t a -> bool;
      }.
      Arguments signature : clear implicits.
    End MAP.

## Records
In&nbsp;Coq, the fields of a record are projection functions which live in the same namespace as the values. Thus&nbsp;Coq is more prone to name collisions for record fields than&nbsp;OCaml. We solve this issue by putting the record definitions into modules of the same name. For example, for the record:

    type descr = {name : string; descr : string option}

we generate the following&nbsp;Coq code:

    Module descr.
      Record record := {
        name : string;
        descr : option string }.
    End descr.
    Definition descr := descr.record.

We thus prevent a name collision between the record type&nbsp;`descr` and the record field&nbsp;`descr`.

In subsequent accesses to the record fields, we prefix the projections by the record name. For example, to access to the&nbsp;`name` field of a record instance&nbsp;`r` of&nbsp;`descr`, we write in&nbsp;Coq:

    r.(descr.name)

## Pretty-printing
We improved the pretty-printing for the types. In particular:

* we limit the number of parenthesis by taking into account the precedence of the operators;
* we use a more consistent indentation.

As an example, we moved from the following generated&nbsp;Coq:

    | FLambda : Z -> (list ((Context.binder_annot Names.Name.t) * Constr.constr)) ->
      Constr.constr -> (Esubst.subs fconstr) -> fterm

to:

    | FLambda :
      Z -> list (Context.binder_annot Names.Name.t * Constr.constr) ->
      Constr.constr -> Esubst.subs fconstr -> fterm

## Conclusion
We generated around six thousands valid&nbsp;Coq lines. Some&nbsp;OCaml constructs were missing, such as the extensible types. We may not support them as we see no direct equivalents in&nbsp;Coq. There is also a lot of code duplication due to the repetitive inclusion of similar module signatures. We will try to find solutions to factorize the generated code.

Finally, we will see if the code for the&nbsp;Tezos interface is usable when applying&nbsp;`coq-of-ocaml` to the protocol implementation.
