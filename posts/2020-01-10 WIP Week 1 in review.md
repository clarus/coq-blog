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
