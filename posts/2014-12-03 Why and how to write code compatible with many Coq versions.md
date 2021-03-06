You should always write your code to make it compatible with at least two consecutive Coq versions, if you wish to have larger people adoption.

The pace of Coq releases is surprisingly slow for a project with that many users, unfortunately due to a lack of organization resources. However, the releases happen and usually introduce a lot of incompatibilities. At this point, users depending on your libraries may be forced to migrate because of other dependencies, or forced not to migrate. Playing nice with them means allowing them to have the choice.

More important, a lot of people prefer to use the development version of Coq because of the slow release cycle. So your code should at least support the latest stable release and the current development version.

## Check your code
[OPAM](http://opam.ocamlpro.com/) is the best way to test your code with different versions of Coq. You can read this [introduction](http://coq-blog.clarus.me/use-opam-for-coq.html) to learn more about how to use OPAM for Coq.

Let us say we want to test our project `foo` with the Coq versions `8.4.5` and `dev`. We create two installs of Coq in `foo/opam.8.4.5` and `foo/opam.dev`. For the stable version:

    cd foo/
    mkdir opam.8.4.5 # we create the empty directory to prevent a bug of OPAM
    opam init --root=opam.8.4.5
    eval `opam config --root=opam.8.4.5 env`
    opam install --jobs=4 coq.8.4.5

In an other terminal, for the unstable Coq:

    mkdir opam.dev
    opam init --root=opam.dev
    eval `opam config --root=opam.dev env`
    opam repo add coq-core-dev https://coq.inria.fr/opam/core-dev
    opam install -j4 -v coq.dev

You have now a different version of Coq in each terminal, and can test your code for two versions. If you have an old computer, and may be afraid of having many Coq installations for each project, remember you can always use cache mechanisms like the one provided by [Docker](https://www.docker.com/) to save disk space.

We also provide a [coq-bench](http://coq-bench.github.io/) website, where OPAM packages are tested for different versions of Coq. This is another simple way to check your code compatibility if you have a package.

## Be clean and robust
This is obvious but this must be emphasized: be clean and robust. Most Coq features outside the kernel can be considered as experimental, or do not have a clear semantics. This includes in particular the tactic language [LTac](https://coq.inria.fr/distrib/V8.4pl5/refman/Reference-Manual012.html).

So try not to rely too much on advanced features, and make your proofs scripts robust (using [explicitly named variables](http://poleiro.info/posts/2013-11-17-automatic-naming-considered-harmful.html) or [bullets](http://poleiro.info/posts/2013-06-27-structuring-proofs-with-bullets.html) for example).

## Preprocess
You can use preprocessing to solve breaking incompatibility changes. This helps to keep one code database, instead of splitting your developments with one branch per Coq version.

Some people use the [CPP preprocessor](http://en.wikipedia.org/wiki/C_preprocessor), but it has a heavy syntax and is quite limited. Instead, I recommend to go for simpler and more powerful tools like [ERB](http://en.wikipedia.org/wiki/ERuby). Here is an example file `Test.v`:

    Definition proj (n : {n : nat & n >= 2}) : nat :=
      match n with
      | existT n _ => n
      end.

This code will not work with `coq.dev` as you need one more argument in the `match`:

    Definition proj (n : {n : nat & n >= 2}) : nat :=
      match n with
      | existT _ n _ => n
      end.

The solution is to make a `Test.v.erb` file, which will be preprocessed into `Test.v`:

    Definition proj (n : {n : nat & n >= 2}) : nat :=
      match n with
      | existT <%= "_" unless version[0..2] == "8.4" %> n _ => n
      end.

We add a `_` in the `match`, unless if the Coq version starts by `8.4`. Other common constructs are:

    <%= "bla" if version[0..2] == "8.4" %>
    <%= version[0..2] == "8.4" ? "bla" : "bli" %>

To preprocess this `Test.v.erb` file, create a `pp.rb` file at the root of your directory:

    # Preprocessor.
    require 'erb'

    # The version of Coq.
    version = `coqc -v`.match(/version ([^(]*) \(/)[1]

    Dir.glob("*.v.erb") do |file_name|
      renderer = ERB.new(File.read(file_name, encoding: "UTF-8"))
      output_name = file_name[0..-5]
      File.open(output_name, "w") do |file|
        file << renderer.result()
      end
      puts "#{file_name} -> #{output_name}"
    end

The command `ruby pp.rb` will then compile all the files matching `*.v.erb` to `*.v`.

**Edit from the comments:**
To integrate preprocessing with an IDE, you can use the [ProofGeneral's plugin](https://gist.github.com/cpitclaudel/2c75c8dc88b0e1c9a6e7) of [Clément Pit-Claudel](http://pit-claudel.fr/clement/). For other IDEs, the only solution is to edit the `.v` files in the IDE for one specific version of Coq, and do back-and-forths with the `.v.erb` files to add compatibility.
