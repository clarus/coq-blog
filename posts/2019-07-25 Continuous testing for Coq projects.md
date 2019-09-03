Testing that a Coq project works with different Coq versions may be time consuming. This is necessary to deliver with confidence new project releases. We show a setup to run automated testing with [Travis CI](https://travis-ci.org/) in [GitHub](https://github.com/) using pre-compiled Coq instances. Thanks to that setup we can check new pull-requests in a few minutes for small projects.

This configuration is directly inspired by the [CI setup](https://github.com/coq-community/docker-coq/wiki/CI-setup) documentation written by [Erik Martin-Dorel](https://github.com/erikmd).

![Travis CI report on a pull-request](static/images/travis-ci/build-report.png "Travis CI report on a pull-request")

## Setting up Travis CI
To setup Travis CI, we take the example of the [github.com/coq-io/system](https://github.com/coq-io/system) project. We need to create two files at the root of the project:

* `coq-io-system.opam` to describe the dependencies;
* `.travis.yml` to configure and activate Travis CI.

## Describing the dependencies
We create a file `coq-io-system.opam` with the following content:

    opam-version: "2.0"
    maintainer: "dev@clarus.me"
    homepage: "https://github.com/clarus/io-system"
    dev-repo: "git+https://github.com/clarus/io-system.git"
    bug-reports: "https://github.com/clarus/io-system/issues"
    authors: ["Guillaume Claret"]
    license: "MIT"
    build: [
      ["./configure.sh"]
      [make "-j%{jobs}%"]
    ]
    install: [
      [make "install"]
    ]
    depends: [
      "ocaml"
      "coq" {>= "8.5"}
      "coq-function-ninjas"
      "coq-list-string" {>= "2.0.0"}
      "coq-io" {>= "4.0.0"}
      "coq-io-system-ocaml" {>= "2.3.0"}
    ]
    tags: [
      "keyword:effects"
      "keyword:extraction"
      "logpath:Io/System"
    ]
    synopsis: "System effects for Coq"

This file describes the dependencies of the project. It can list any other opam packages published on the [OCaml repository](https://opam.ocaml.org/) or the [Coq repository](https://github.com/coq/opam-coq-archive). We also give the build and install commands. To check that this file is correct:

    # linting to check for typos
    opam lint coq-io-system.opam
    # adding the Coq repository if not already done
    opam repo add coq-released https://coq.inria.fr/opam/released
    # installing the package
    opam pin add coq-io-system.opam . --kind=path

## Configuring Travis CI
We add a file `.travis.yml` with the following content:

    dist: trusty
    sudo: required
    language: generic

    services:
      - docker

    env:
      global:
      - PACKAGE_NAME="coq-io-system"
      matrix:
      - COQ_IMAGE="coqorg/coq:8.4"
      - COQ_IMAGE="coqorg/coq:8.5" SHOULD_SUPPORT="true"
      - COQ_IMAGE="coqorg/coq:8.6" SHOULD_SUPPORT="true"
      - COQ_IMAGE="coqorg/coq:8.7" SHOULD_SUPPORT="true"
      - COQ_IMAGE="coqorg/coq:8.8" SHOULD_SUPPORT="true"
      - COQ_IMAGE="coqorg/coq:8.9" SHOULD_SUPPORT="true"

    install: |
      # Prepare the COQ container
      docker pull ${COQ_IMAGE}
      docker run -d -i --init --name=COQ -v ${TRAVIS_BUILD_DIR}:/home/project -w /home/project ${COQ_IMAGE}
      docker exec COQ /bin/bash --login -c "
        # This bash script is double-quoted to interpolate Travis CI env vars:
        echo \"Build triggered by ${TRAVIS_EVENT_TYPE}\"
        export PS4='+ \e[33;1m(\$0 @ line \$LINENO) \$\e[0m '
        set -ex  # -e = exit on failure; -x = trace for debug
        opam update
        opam pin add ${PACKAGE_NAME}.opam . --kind=path --no-action
        opam config list
        opam repo list
        opam pin list
        opam list
        " install
    script:
    - echo -e "${ANSI_YELLOW}Building...${ANSI_RESET}" && echo -en 'travis_fold:start:script\\r'
    - |
      docker exec COQ /bin/bash --login -c "
        export PS4='+ \e[33;1m(\$0 @ line \$LINENO) \$\e[0m '
        set -ex
        sudo chown -R coq:coq /home/project
        # Check if the package is compatible with the current environment
        if [ ${SHOULD_SUPPORT} ] || opam install ${PACKAGE_NAME} --show-action; then
          # First install the dependencies
          opam install ${PACKAGE_NAME} --deps-only -y
          opam list
          # Then install the package itself in verbose mode
          opam install ${PACKAGE_NAME} -v
        fi;
        " script
    - docker stop COQ  # optional
    - echo -en 'travis_fold:end:script\\r'

This YAML file explains to [Travis CI](https://travis-ci.org/) what to do to check the project. We use the [coqorg/coq](https://hub.docker.com/r/coqorg/coq) Docker images. These images have pre-compiled versions of Coq with opam to speedup the tests. For each architecture from Coq `8.4` to Coq `8.9` we:

* check if either:
  * the platform is supposed to be supported `if [ ${SHOULD_SUPPORT} ]`,
  * or if opam considers the platform as compatible `opam install ${PACKAGE_NAME} --show-action`;
* install the dependencies `opam install ${PACKAGE_NAME} --deps-only -y`;
* install the project in verbose mode `opam install ${PACKAGE_NAME} -v`.

## Using Travis CI
You may need to activate Travis CI for your project in the [settings page](https://travis-ci.org/account/repositories):

![Enabling Travis CI](static/images/travis-ci/enabling.png "Enabling Travis CI")

Then for each pull-request you will see a green or red mark precising if the project passed the tests, along with detailed logs:

![Validated pull-request](static/images/travis-ci/pull-request.png "Commits in a pull-request")