I will show here a typical workflow to create and publish a Coq package on [OPAM](http://opam.ocamlpro.com/). This will allow you to share your Coq developments in a simple way to gain in visibility. Other researchers will just need a:

    opam install coq:that-super-proof

to see that what you did *actually* works. We hope it will become the norm in the near future.

## Create a project
Go on [GitHub](https://github.com/) and make a new project. To get the best chances to be reviewed, it is a good practice to always chose the tools that most people use. Today, GitHub is the most popular hosting platform for projects, and a pull-request (external contribution) is a matter of a click.

Clone your repository to, for example, `that-super-proof/`. Add an `LICENSE` file with your copyright if you want your package to be open-source (by default, a code is considered proprietary). The [MIT](http://opensource.org/licenses/MIT) license is one of the most permissive and popular licenses:

    The MIT License (MIT)

    Copyright (c) <year> <copyright holders>

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
    THE SOFTWARE.

Add a main file `All.v`:

    Theorem two : 1 + 1 = 2.
      now admit.
    Qed.

You can commit your work.

## Compile
We will use `coq_makefile`. Add a project file `Make`:

    -R . ThatSuperProof

    All.v

and an executable script `configure.sh`:

    #!/bin/sh

    coq_makefile -f Make -o Makefile

Now compile with:

    ./configure.sh
    make

Coq Makefile is clever and will also generate an `install` rule, among over things.

## Publish a development version

## Make a stable release

## Use the bench
