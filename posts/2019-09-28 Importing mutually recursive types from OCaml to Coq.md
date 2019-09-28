In order to make [coq-of-ocaml](https://github.com/clarus/coq-of-ocaml) usable on a maximum of [OCaml](https://ocaml.org/) programs we must handle mutually recursive types. We show how we import these types to [Coq](https://coq.inria.fr/) and the main differences between the two languages. As a result, more OCaml programming patterns should be supported by coq-of-ocaml.

## Example
Take the following mutually recursive definition of a tree in OCaml:

    type 'a tree = Tree of 'a node list

    and 'a node =
      | Leaf of 'a leaf
      | Node of 'a tree

    and 'content leaf = string * 'content

By applying [coq-of-ocaml](https://github.com/clarus/coq-of-ocaml) on this code we get:

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

We transform algebraic data types to Coq's inductive types. We use a notation to implement the type synonym `leaf`. This is a trick because Coq only supports inductive types in mutual definitions. See the [documentation on notations](https://coq.inria.fr/refman/user-extensions/syntax-extensions.html?highlight=notation#reserving-notations). We name the `leaf` type parameter `'content` instead of `'a` to avoid a name collision in Coq. The type parameters of the constructors are set implicit with the command `Arguments` as they would be implicit too in OCaml.

## General mechanism
...

## Limitations
...
