## Polymorphic variants
In&nbsp;OCaml we can tag sum types with the backquote operator as follows:

    type json =
      [ `O of (string * json) list
      | `Bool of bool
      | `Float of float
      | `A of json list
      | `Null
      | `String of string ]

There are no direct equivalents in&nbsp;Coq and we generate an error message when we encounter them. Still, we generate some code as a first approximation. For type definitions we generate a&nbsp;Coq inductive:

    Inductive json : Set :=
    | Bool : bool -> json
    | Null : json
    | O : list (string * json) -> json
    | Float : Z -> json
    | String : string -> json
    | A : list json -> json.

For inlined variants:

    val fold :
      t ->
      key ->
      init:'a ->
      f:([`Key of key | `Dir of key] -> 'a -> 'a Lwt.t) ->
      'a Lwt.t

we generate a sum with the tags as comments:

    Parameter fold : forall {a : Set},
      t -> key -> a -> ((* `Dir *) key + (* `Key *) key -> a -> Lwt.t a) ->
      Lwt.t a.

## Name collisions
In contrast to&nbsp;OCaml, types and values live in the same namespace in&nbsp;Coq. Thus there are often name collisions in the generated&nbsp;Coq. Typically, this is due to the use of values having the same name as their type. We prevent that for the common cases&nbsp;(`list`, `string`, ...) by translating the value names with a&nbsp;`_value` suffix. For example, we convert:

    val string : string encoding

to:

    Parameter __string_value : encoding string.

## Modules
We now import the definition of module types in&nbsp;`.mli` files as this was not done before. The code to do so is the same as for&nbsp;`.ml` files. For example, we import:

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

We handle the import of modules declared with a signature by unfolding the signature. This is because we do not represent signatures in&nbsp;Coq unless for first-class modules&nbsp;(using a record). For example, we import:

    module String : COMPARABLE with type t = string

to:

    Module String.
      Definition t := string.
      
      Parameter compare : t -> t -> Z.
    End String.

This idea is due to&nbsp;[Mehdi Bouaziz](https://fr.linkedin.com/in/mehdibouaziz).

We also handle the&nbsp;`include` keyword by doing a similar unfolding. The unfolding of&nbsp;`include` significantly increases the size of the&nbsp;Coq code for the Tezos protocol interface. Indeed, the number of generated lines for the interface is multiplied by two.

## First-class modules
We improved the detection of first-class modules. The detection of first-class modules is a challenge in&nbsp;`coq-of-ocaml`. Indeed, we need to distinguish between first-class and plain modules in order to generated either a dependent record or a&nbsp;Coq module. Moreover, there are no builtin ways to translate between a record and a module in&nbsp;Coq.

When we access to the field of a module, we consider this module as a&nbsp;Coq record when it:

* has a named signature (to have a corresponding named record definition);
* is locally opened in an expression.

We added the constraint of being locally opened in order to filter out some plain modules with a named signature. We may change this rule in the future and convert more plain modules to records by default, as this may factorize the generated code.

To handle first-class modules with polymorphic abstract types, we detect and mark the arity of the type parameters. For example, for a map signature in&nbsp;OCaml:

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
In&nbsp;Coq, the fields of a record are projections functions which live in the same namespace as values. Thus&nbsp;Coq is more prone to name collisions for record fields than&nbsp;OCaml. We solve this issue by putting the record definitions into modules of the same name. For example, for the record:

    type descr = {name : string; descr : string option}

we generate the following&nbsp;Coq code:

    Module descr.
      Record record := {
        name : string;
        descr : option string }.
    End descr.
    Definition descr := descr.record.

preventing a name collision between the record type&nbsp;`descr` and the record field&nbsp;`descr`.

In subsequent accesses to the record fields, we prefix the projections by the record name. For example, to access to the&nbsp;`name` field of a record instance&nbsp;`r`, we write in&nbsp;Coq:

    descr.name r

## Pretty-printing
We improved the pretty-printing for the types. In particular:

* we limit the number of parenthesis by taking into account the precedence of the operators;
* we use a more consistent indentation.

As an example, we move from the generated&nbsp;Coq:

    | FLambda : Z -> (list ((Context.binder_annot Names.Name.t) * Constr.constr)) ->
      Constr.constr -> (Esubst.subs fconstr) -> fterm

to:

    | FLambda :
      Z -> list (Context.binder_annot Names.Name.t * Constr.constr) ->
      Constr.constr -> Esubst.subs fconstr -> fterm
