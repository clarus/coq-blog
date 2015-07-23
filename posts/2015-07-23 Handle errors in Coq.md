Many programming languages handle errors with an exceptions mechanism. There are no exceptions in [Coq](https://coq.inria.fr/), since this is a pure programming language. We mainly get two alternatives:

1. extend Coq with an effect system for exceptions, implemented with monads or alike
2. use explicit sum types

Even if the first option seems more powerful, from my experience an effect system is to heavy for the gains it brings compared the use of sum types with combinators. Sum types are just *simple* and *ubiquitous*. This is in fact the way errors are handled in [Rust](http://blog.burntsushi.net/rust-error-handling/).


