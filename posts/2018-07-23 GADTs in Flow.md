The [GADTs (Generalized algebraic data types)](https://en.wikipedia.org/wiki/Generalized_algebraic_data_type#Higher-order_abstract_syntax) are a generalization of sum types where the type parameter can change in each case. GADTs are not available in [Flow](https://flow.org/) but we show a technique to approximate them.

## Use case
Let us say we want to implement an evaluator for simple arithmetic expressions. We define the type of expressions:

    type Expr = {
      type: 'I',
      value: number
    } | {
      type: 'B',
      value: boolean
    } | {
      type: 'Add',
      x: Expr,
      y: Expr
    } | {
      type: 'Mul',
      x: Expr,
      y: Expr
    } | {
      type: 'Eq',
      x: Expr,
      y: Expr
    };

and an evaluation function:

    function evaluate(expr: Expr): boolean | number {
      switch (expr.type) {
        case 'I':
          return expr.value;
        case 'B':
          return expr.value;
        case 'Add':
          return evaluate(expr.x) + evaluate(expr.y);
        case 'Mul':
          return evaluate(expr.x) * evaluate(expr.y);
        case 'Eq':
          return evaluate(expr.x) === evaluate(expr.y);
        default:
          return expr;
      }
    }

but we get a Flow error:

    32:  return evaluate(expr.x) * evaluate(expr.y);
                ^ Cannot perform arithmetic operation because boolean [1] is not a number.
    References:
    23: function evaluate(expr: Expr): boolean | number {
                                       ^ [1]

This is because the type `Expr` does not prevent to write invalid expressions such as multiplications over booleans:

    const foo: Expr = {
      type: 'Mul',
      x: {type: 'B', value: true},
      y: {type: 'B', value: false}
    };

We would like to distinguish between expressions which evaluate to a `boolean` and expressions which evaluate to a `number`.

## GADTs
GADTs allow exactly that. In [Haskell](https://www.haskell.org/) we can define a type `Expr a` (with `a` the type of the evaluation result) as follows:

    data Expr a where
      B :: Bool -> Expr Bool
      I :: Int -> Expr Int
      Add :: Expr Int -> Expr Int -> Expr Int
      Mult :: Expr Int -> Expr Int -> Expr Int
      Eq :: Expr Int -> Expr Int -> Expr Bool

    evaluate :: Expr a -> a
    evaluate expr = ...

Unfortunately, Flow has no syntax to express this kind of types:

    type Expr<A> = {
      type: 'I', // Where do we say this is Expr<number>?
      value: number
    } | {
      type: 'B', // Where do we say this is Expr<boolean>?
      value: boolean
    } | {
      ...

## Encoding in Flow
We use a trick to encode GATDs in Flow. We express that in the case `type: 'I'` of an expression of type `Expr<A>` the type `A` is actually a `number` by adding an _equality witness_ `_eq` between `A` and `number`:

    type Expr<A> = {
      type: 'I',
      _eq: number => A,
      value: number
    } | {
      ...

We force ourselves to only provide the identity function for `_eq` to make the equality witness valid:

    function i(value: number): Expr<number> {
      return {type: 'I', _eq: x => x, value};
    }

The full defintion:

    type Expr<A> = {
      type: 'I',
      _eq: number => A,
      value: number
    } | {
      type: 'B',
      _eq: boolean => A,
      value: boolean
    } | {
      type: 'Add',
      _eq: number => A,
      x: Expr<number>,
      y: Expr<number>
    } | {
      type: 'Mul',
      _eq: number => A,
      x: Expr<number>,
      y: Expr<number>
    } | {
      type: 'Eq',
      _eq: boolean => A,
      x: Expr<number>,
      y: Expr<number>
    };

and all the wrappers:

    function i(value: number): Expr<number> {
      return {type: 'I', _eq: x => x, value};
    }

    function b(value: boolean): Expr<boolean> {
      return {type: 'B', _eq: x => x, value};
    }

    function add(x: Expr<number>, y: Expr<number>): Expr<number> {
      return {type: 'Add', _eq: x => x, x, y};
    }

    function mul(x: Expr<number>, y: Expr<number>): Expr<number> {
      return {type: 'Mul', _eq: x => x, x, y};
    }

    function eq(x: Expr<number>, y: Expr<number>): Expr<boolean> {
      return {type: 'Eq', _eq: x => x, x, y};
    }

We can then define a well-typed `evaluate` function by applying the `_eq` witness to use the type equalities when needed:

    function evaluate<A>(expr: Expr<A>): A {
      switch (expr.type) {
        case 'I':
          return expr._eq(expr.value);
        case 'B':
          return expr._eq(expr.value);
        case 'Add':
          return expr._eq(evaluate(expr.x) + evaluate(expr.y));
        case 'Mul':
          return expr._eq(evaluate(expr.x) * evaluate(expr.y));
        case 'Eq':
          return expr._eq(evaluate(expr.x) === evaluate(expr.y));
        default:
          return expr;
      }
    }

    const e1: Expr<number> = add(i(2), i(4));
    const e2: Expr<number> = mul(i(2), i(3));
    const e3: Expr<boolean> = eq(e1, e2);
    console.log(evaluate(e1), evaluate(e2), evaluate(e3));

Note that `_eq` has no runtime value, is only here for typing and could be eliminated given a clever enough compiler / interpreter.

## Robustness
We test the effectiveness of this encoding by introducing some errors in our code. In the definition of expressions:

* mistake:

        const e1: Expr<boolean> = add(i(2), i(4));

* Flow output:

        const e1: Expr<boolean> = add(i(2), i(4));
                                  ^ Cannot assign `add(...)` to `e1` because number [1] is incompatible with boolean [2] in type argument `A` [3].

In the definition of `evaluate`, if we return a `boolean` where we expect a `number`:

* mistake:

        case 'Mul':
          return expr._eq(evaluate(expr.x) === evaluate(expr.y));

* Flow output:

        return expr._eq(evaluate(expr.x) === evaluate(expr.y));
                        ^ Cannot call `expr._eq` with `evaluate(...) === evaluate(...)` bound to the first parameter because boolean [1] is incompatible with number [2].

If we do not use `_eq`:

* mistake:

        case 'Mul':
          return evaluate(expr.x) * evaluate(expr.y);

* Flow output:

        return evaluate(expr.x) * evaluate(expr.y);
               ^ Cannot return `evaluate(...) * evaluate(...)` because number [1] is incompatible with `A` [2].

A weakness of this encoding is that we must enforce by hand that `_eq` is always `x => x`.

## Related
The idea of using type equalities is taken from [Approximating GADTs in PureScript](http://code.slipthrough.net/2016/08/10/approximating-gadts-in-purescript/). In [PureScript](http://www.purescript.org/) the type system almost enforces that `_eq` is the identity (it could also be a non-terminating function). There is a [thread](https://github.com/facebook/flow/issues/1356) on GitHub issues discussing the addition of GADTs to Flow (currently closed).
