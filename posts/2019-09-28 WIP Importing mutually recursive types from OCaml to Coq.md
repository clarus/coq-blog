In order to make&nbsp;[coq-of-ocaml](https://github.com/clarus/coq-of-ocaml) usable on a maximum of&nbsp;[OCaml](https://ocaml.org/) programs, we should handle mutually recursive types. We show how we import these types to&nbsp;[Coq](https://coq.inria.fr/) and the main differences between the two languages. As a result, more&nbsp;OCaml programming patterns should be supported by&nbsp;coq-of-ocaml.

## Example
Take the following mutually recursive definition of a tree in&nbsp;OCaml:

    type 'a tree = Tree of 'a node list

    and 'a node =
      | Leaf of 'a leaf
      | Node of 'a tree

    and 'content leaf = string * 'content

By applying&nbsp;[coq-of-ocaml](https://github.com/clarus/coq-of-ocaml) on this code we get:

    Reserved Notation "'leaf".

    Inductive tree (a : Type) : Type :=
    | Tree : (list (node a)) -> tree a

    with node (a : Type) : Type :=
    | Leaf : ('leaf a) -> node a
    | Node : (tree a) -> node a

    where "'leaf" := (fun (content : Type) => string * content).

    Definition leaf := 'leaf.

    Arguments Tree {_}.
    Arguments Leaf {_}.
    Arguments Node {_}.

We transform algebraic data types to&nbsp;Coq's inductive types. We use a notation to implement the type synonym&nbsp;`leaf`. This is a trick because Coq only supports inductive types in mutual definitions. See the [documentation on notations](https://coq.inria.fr/refman/user-extensions/syntax-extensions.html?highlight=notation#reserving-notations) for more information. We rename the&nbsp;`leaf` type parameter&nbsp;`'content` instead of&nbsp;`'a` to avoid a name collision in&nbsp;Coq. The type parameters of the constructors are set implicit with the command&nbsp;`Arguments` to keep the behavior of&nbsp;OCaml.

## General mechanism
We handle&nbsp;`type ... and ...` definitions with algebraic data types (including&nbsp;GADTs) and type synonyms. We do not handle abstract types. For records in mutual definitions, one can use a type synonym to a more generic record. For example:

    type expression =
      | Number of int
      | Operation of operation

    and operation = {
      name : string;
      parameters : expression list }

can be rewritten as:

    type 'a operation_skeleton = {
      name : string;
      parameters : 'a list }

    type expression =
      | Number of int
      | Operation of operation

    and operation = expression operation_skeleton

in order to be imported into&nbsp;Coq.

In&nbsp;Coq, there is a distinction between type variables on the left and on the right of the&nbsp;`:`:

    Inductive t (A1 A2 ... : Type) : forall (B1 B2 ... : Type), Type :=
    | Constr1 : ... -> t A1 A2 ... C1 C2 ...
    | ...

The variables&nbsp;`Ai` do not behave the same as the variables&nbsp;`Bi`. Type variables on the left have the constraint to be the same for each constructor. When used, they simplify the typing of the pattern matching. Typically, in&nbsp;GADTs, type variables are on the right while in non-GADT algebraic data types there are on the left. In mutually recursive inductive types there is one more constraint: the type variables on the left must be the same for each type. We consider a type variable to be "on the left" if it appear with the same name in each&nbsp;OCaml constructor and the type name definition. For example:

    type ('a, 'b) arith =
      | Int : 'a * int -> ('a, int) arith
      | Eq : 'a * ('a, int) arith * ('a, int) arith -> ('a, bool) arith
      | Plus : 'a * ('a, int) arith * ('a, int) arith -> ('a, int) arith

is imported to:

    Inductive arith (a : Type) : forall (b : Type), Type :=
    | Int : a -> Z -> arith a Z
    | Eq : a -> (arith a Z) -> (arith a Z) -> arith a bool
    | Plus : a -> (arith a Z) -> (arith a Z) -> arith a Z.

    Arguments Int {_}.
    Arguments Eq {_}.
    Arguments Plus {_}.

Here `'a` becomes a "left" variable and `'b` a right variable.

## Limitations
Many&nbsp;OCaml programs define all types as mutually recursive by default. In&nbsp;Coq this is usually very difficult as:

* only algebraic and synonym types can be mutual;
* all type variables on the left must be the same;
* the "strictly positive" constraint in&nbsp;Coq prevents some constructions (such as having a type as a type parameter for another);
* the proofs or the definition of recursive functions on mutually recursive types is more complicated than with simple recursive types.

In practice, I would recommend to find a way to avoid mutually recursive types when possible. For cases they are used, I hope this import mechanism to be useful.
