In this blog post, we will show how we [formally verify](https://en.wikipedia.org/wiki/Formal_verification) in [Coq](https://coq.inria.fr/) some properties about the parser of [smart-contracts](https://en.wikipedia.org/wiki/Smart_contract) for the crypto-currency [Tezos](https://tezos.com/). The [proofs of this formal verification](https://gitlab.com/nomadic-labs/coq-tezos-of-ocaml/-/tree/master/src/Proto_alpha/Proofs/Script_ir_translator) are hosted in our project [coq-tezos-of-ocaml](https://gitlab.com/nomadic-labs/coq-tezos-of-ocaml).

To get a formalization of the [implementation of the parser](https://gitlab.com/tezos/tezos/-/blob/master/src/proto_alpha/lib_protocol/script_ir_translator.ml), written in [OCaml](https://ocaml.org/), we use the tool [coq-of-ocaml](https://clarus.github.io/coq-of-ocaml/) to convert it automatically to Coq. We will talk about the tricks we used to get this conversion to work, in particular for the GADTs and the mutually recursive functions. We will also present the properties which we verified and how we did it.

> We develop coq-of-ocaml at [Nomadic Labs](https://www.nomadic-labs.com/) with the aim to formally verify OCaml programs, and in particular the implementation of the crypto-currency [Tezos](https://tezos.com/). If you want to use this tool for your own projects, please do not hesitate to look at the [coq-of-ocaml website](https://clarus.github.io/coq-of-ocaml/) or [contact us](mailto:contact@nomadic-labs.com)!

## How do we convert the OCaml code to Coq
The code which we are interested into is in the file [`script_ir_translator.ml`](https://gitlab.com/tezos/tezos/-/blob/master/src/proto_alpha/lib_protocol/script_ir_translator.ml). This is a long file, containing in particular the parser and type-checker of the [Michelson](https://wiki.tezosagora.org/files/language.html#michelson) language for smart-contracts. We are interested into the functions "parse something" and "unparse something" to show that there are compatible. We use the tool coq-of-ocaml to convert the code of this file. Since it depends on other files of the code of Tezos (for type definitions or primitives), we need to have the Coq definition of all its dependencies too. This is done in the project [coq-tezos-of-ocaml](https://gitlab.com/nomadic-labs/coq-tezos-of-ocaml). The translation of `script_ir_translator.ml` is in [src/Proto\_alpha/Script\_ir\_translator.v](https://gitlab.com/nomadic-labs/coq-tezos-of-ocaml/-/blob/master/src/Proto_alpha/Script_ir_translator.v).

### Mutually recursive functions
Mutually recursive functions are a challenge in Coq because of the syntactic constraints to make sure that each function terminates. Indeed, termination is important for Coq because a non-terminating functions would make the whole system logically inconsistent. Moreover, OCaml programs may not follow the syntactic constraints for termination of Coq as the OCaml compiler does not check for termination. Thus we use several techniques to translate the OCaml code to Coq without modifying too much the source:

* disabling if needed the termination checker of Coq with the [`Guard Checking`](https://coq.inria.fr/refman/proof-engine/vernacular-commands.html#coq:flag.Guard-Checking) flag;
* introducing [OCaml attributes](https://clarus.github.io/coq-of-ocaml/docs/attributes) to guide the translation.

There are two main attributes useful to translate recursive functions:

* `@coq_struct "ident"` to specify the `{struct ident}` parameter of the [`Fixpoint`](https://coq.inria.fr/refman/language/core/inductive.html#coq:cmd.Fixpoint) command of Coq;
* `@coq_mutual_as_notation` to force some mutual functions to be defined as notations.

For example, let us we take the function `parse_ty` to parse types, defined in OCaml as:

    let rec parse_ty =
     fun ctxt
        ~legacy
        ~allow_lazy_storage
        ~allow_operation
        ~allow_contract
        ~allow_ticket
        node ->
      Gas.consume ctxt Typecheck_costs.parse_type_cycle
      >>? fun ctxt ->
      match node with
      | Prim (_loc, T_unit, [], _annot) ->
          ok (Ex_ty Unit_t, ctxt)
      | Prim (_loc, T_int, [], _annot) ->
          ok (Ex_ty Int_t, ctxt)
      | Prim (_loc, T_nat, [], _annot) ->
          ok (Ex_ty Nat_t, ctxt)
      | Prim (_loc, T_string, [], _annot) ->
          ok (Ex_ty String_t, ctxt)
      | Prim (_loc, T_bytes, [], _annot) ->
          ok (Ex_ty Bytes_t, ctxt)
      | Prim (_loc, T_mutez, [], _annot) ->
          ok (Ex_ty Mutez_t, ctxt)
      | Prim (_loc, T_bool, [], _annot) ->
          ok (Ex_ty Bool_t, ctxt)
      [...]

    and parse_parameter_ty =
     fun ctxt ~legacy ->
      parse_ty
        ctxt
        ~legacy
        ~allow_lazy_storage:true
        ~allow_operation:false
        ~allow_contract:true
        ~allow_ticket:true

    and parse_any_ty =
      [...]

We have one main function `parse_ty` iterating over the parameter `node` and several auxiliary functions such as `parse_parameter_ty` which are exposed at top-level. We represent these auxiliary functions as notations in Coq, so that they are simpler to reason about compared to mutual fixpoints. We annotate the `parse_parameter_ty` function by the `@coq_mutual_as_notation` attribute so that we generate in Coq:

    Reserved Notation "'parse_parameter_ty".
    Reserved Notation "'parse_any_ty".
    [...]

    Fixpoint parse_ty
      (ctxt : Alpha_context.context) (legacy : bool) (allow_lazy_storage : bool)
      (allow_operation : bool) (allow_contract : bool) (allow_ticket : bool)
      (node : Alpha_context.Script.node) {struct node}
      : M? (ex_ty * Alpha_context.context) :=
      let parse_parameter_ty := 'parse_parameter_ty in
      let parse_any_ty := 'parse_any_ty in
      [...]
      let? ctxt := Alpha_context.Gas.consume ctxt Typecheck_costs.parse_type_cycle
        in
      match
        (node,
          match node with
          | Micheline.Prim loc Michelson_v1_primitives.T_big_map args _annot =>
            allow_lazy_storage
          | _ => false
          end,
          match node with
          |
            Micheline.Prim _loc Michelson_v1_primitives.T_sapling_state
              (cons memo_size []) _annot => allow_lazy_storage
          | _ => false
          end) with
      | (Micheline.Prim _loc Michelson_v1_primitives.T_unit [] _annot, _, _) =>
        return? ((Ex_ty Script_typed_ir.Unit_t), ctxt)
      | (Micheline.Prim _loc Michelson_v1_primitives.T_int [] _annot, _, _) =>
        return? ((Ex_ty Script_typed_ir.Int_t), ctxt)
      | (Micheline.Prim _loc Michelson_v1_primitives.T_nat [] _annot, _, _) =>
        return? ((Ex_ty Script_typed_ir.Nat_t), ctxt)
      | (Micheline.Prim _loc Michelson_v1_primitives.T_string [] _annot, _, _) =>
        return? ((Ex_ty Script_typed_ir.String_t), ctxt)
      [...]

    where "'parse_parameter_ty" :=
      (fun (ctxt : Alpha_context.context) (legacy : bool) =>
        parse_ty ctxt legacy true false true true)

    and "'parse_any_ty" :=
      [...]

    Definition parse_parameter_ty := 'parse_parameter_ty.
    Definition parse_any_ty := 'parse_any_ty.
    [...]

We define `parse_parameter_ty` as a notation `'parse_parameter_ty`. We introduce an alias `parse_parameter_ty` as a standard definition at the end, so that the code depending on `parse_parameter_ty` does not need to know that this is actually a notation. Using the notation, we consider `parse_parameter_ty` as a shorthand to call `parse_ty` rather than a whole new function. This can also simplifies our proofs as `parse_ty` is now a single recursive function.
With the `@coq_struct` attribute, we specify that the parameter `node` is the one to recurse on. Even if the function `parse_ty` is not syntactically terminating for Coq (due to some flattening when parsing pair elements), it is important for the proofs to have a "resonable" `struct` parameter. This prevents the `simpl` tactic to diverge when doing proofs by symbolic evaluation. Here we choose the parameter `node` as it is different on each recursive call.


### GADTs
Our current approach to translate [GADTs](https://caml.inria.fr/pub/docs/manual-ocaml/gadts.html) to Coq is to:

* erase the type parameters;
* use OCaml attributes to force the generation of dynamic casts in Coq when needed (these dynamic casts are axioms).

Fortunately, for our experiment we did not need to use dynamic casts and the code generated without the type parameters for the GADTs was compiling just fine!

## The proofs
All the proofs are accessible online on [coq-tezos-of-ocaml/src/Proto\_alpha/Proofs/Script\_ir\_translator](https://gitlab.com/nomadic-labs/coq-tezos-of-ocaml/-/tree/master/src/Proto_alpha/Proofs/Script_ir_translator). We wanted to verify the following property:

     forall term, parse (unparse term) = term

for the terms of type `comparable_ty` and `ty`. For the type `ty`, we express this property as:

    Lemma parse_unparse_ty
      ctxt
      legacy
      allow_lazy_storage allow_operation allow_contract allow_ticket
      ty
      (H_ty
        : Script_typed_ir.Ty.is_valid
            legacy
            allow_lazy_storage allow_operation allow_contract allow_ticket
            ty =
          true
      )
      : let unlimited_ctxt := Raw_context.with_unlimited_gas ctxt in
        (let? '(node, ctxt) := Script_ir_translator.unparse_ty unlimited_ctxt ty in
        Script_ir_translator.parse_ty
          ctxt
          legacy
          allow_lazy_storage allow_operation allow_contract allow_ticket
          node) =
        return? (Script_ir_translator.Ex_ty ty, unlimited_ctxt).

The parameters `legacy`, `allow_lazy_storage`, `allow_operation`, `allow_contract`, `allow_ticket` are boolean flags of the parsing function. They are mainly there to allow or forbid some elements, such as the contracts or the tickets. The context `ctxt` represents the current state, and in particular contains a reference to the block-chain state. We replace it by:

    let unlimited_ctxt := Raw_context.with_unlimited_gas ctxt in

which is the same context with an unlimited gas value. The gas is there to compute the execution cost for smart-contracts. By setting the gas as unlimited, we avoid having to reason about failures due to gas exhaustion, without too much loss of generality. The `unparse_ty` and `parse_ty` functions are in the error monad, whose basic operators are `return?` to return a success value and `let?` to bind two operations.

We recursively express the pre-condition `Script_typed_ir.Ty.is_valid` on the type `ty`. This pre-condition depends on the same flags as the parsing function. It checks that the forbidden operations are not present, and that all the integers are in the expected intervals.

We do the proof by induction on the value `ty`. The most complex case is the case of pairs because we flatten the pairs to lists of elements, so the induction is not direct. Apart from that case, most of the proof is dedicated to handling the error monad and unfolding the definitions. To get an idea, here is an extract of the Coq proof to handle the general case:

    destruct ty; unfold simple_unparse_ty; simpl; try reflexivity;
      repeat (rewrite simple_unparse_ty_eq; simpl);
      repeat (rewrite Comparable_ty.parse_unparse_comparable_ty; simpl);
      repeat (rewrite (parse_simple_unparse_ty ctxt); simpl);
      trivial;
      simpl in H_ty; try (rewrite Bool.andb_true_iff in H_ty; destruct H_ty);
      trivial.

For each case, we try to do some symbolic evaluation with `simpl`, and apply the inductive hypothesis `parse_simple_unparse_ty` or lemma such as `parse_unparse_comparable_ty`. We also do some basic boolean manipulations with `andb_true_iff` for the pre-condition.
Finally, we check that the pre-condition `Script_typed_ir.Ty.is_valid` is true for all the terms parsed by the function `parse_ty`. We express this property as follows:

    Lemma parse_is_valid
      ctxt
      legacy
      allow_lazy_storage allow_operation allow_contract allow_ticket
      node
      : let result :=
          Script_ir_translator.parse_ty
            ctxt
            legacy
            allow_lazy_storage allow_operation allow_contract allow_ticket
            node in
        match result with
        | Pervasives.Ok (Script_ir_translator.Ex_ty ty, _) =>
          Script_typed_ir.Ty.is_valid
            legacy
            allow_lazy_storage allow_operation allow_contract allow_ticket
            ty =
          true
        | _ => True
        end.

The proof proceeds by induction on the parameter `node`.

## Conclusion
We have seen that we can write basic formal proofs about the parser of smart-contracts of Tezos. We do that first by automatically translating the OCaml code to Coq, and then by doing the proofs in Coq.

We will next focus on writing proofs on the parsing functions for the data of smart-contracts. These functions are slightly more involved than the parsing functions on the types, but follow the same structure.
