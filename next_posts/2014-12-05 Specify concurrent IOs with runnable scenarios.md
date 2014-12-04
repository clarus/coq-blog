Concurrent programs with inputs/outputs are hard to test: they are non-deterministic and interact with the outside world. We will present a novel technique to specify and certify such programs in Coq.

The key idea is to let users describe the behavior of the environment of the program by another program. The environment includes the operating system, other running processes, other computers connected with a socket, ... Talk about mocks, typing.

+ deterministic

## Calculus with handlers
Definition.
### Run
### Examples

## Calculus with binds
Definition.
### Run
### Examples

## Application to a web server

## Future work
