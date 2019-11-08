Testing that a&nbsp;[Coq](https://coq.inria.fr/) project works with different&nbsp;Coq versions may be time consuming. This is necessary to deliver with confidence new project releases.&nbsp;[Travis&nbsp;CI](https://travis-ci.com/) is a service to run tests on&nbsp;[GitHub](https://github.com/) projects and is free for open-source code. We show a setup to run automated testing with&nbsp;Travis&nbsp;CI using pre-compiled&nbsp;Coq instances and [opam](https://opam.ocaml.org/). Thanks to that setup, we can automatically and quickly check new pull-requests and commits.

This configuration is directly inspired by the [CI setup](https://github.com/coq-community/docker-coq/wiki/CI-setup) documentation written by [Erik Martin-Dorel](https://github.com/erikmd).

![Travis CI report on a pull-request](static/images/travis-ci/build-report.png "Travis CI report on a pull-request")

## Setting up Travis CI
To show the setup&nbsp;[Travis&nbsp;CI](https://travis-ci.com/), we take the example of the [github.com/coq-io/system](https://github.com/coq-io/system) project. We need to create two files at the root of the project:

* `coq-io-system.opam` to describe the dependencies;
* `.travis.yml` to configure and activate&nbsp;Travis&nbsp;CI.

## Describing the dependencies
We create an&nbsp;[opam](https://opam.ocaml.org/) file&nbsp;`coq-io-system.opam` with the following content:

    version: "dev"

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
    opam pin add coq-io-system . --kind=path -y

Later on, you may want to publish your package in opam. You can just take this file content and create a pull-request on the [Coq repository](https://github.com/coq/opam-coq-archive). Since this opam file is used for continuous testing, you can be pretty confident that your package is correct.

## Configuring Travis CI
We add a&nbsp;[Travis&nbsp;CI](https://travis-ci.com/) file&nbsp;`.travis.yml` with the following content:

    dist: bionic
    language: generic

    services:
      - docker

    env:
      global:
      - PACKAGE_NAME="coq-io-system"
      matrix:
      - COQ_IMAGE="coqorg/coq:8.4"  SHOULD_SUPPORT="false"
      - COQ_IMAGE="coqorg/coq:8.5"  SHOULD_SUPPORT="true"
      - COQ_IMAGE="coqorg/coq:8.6"  SHOULD_SUPPORT="true"
      - COQ_IMAGE="coqorg/coq:8.7"  SHOULD_SUPPORT="true"
      - COQ_IMAGE="coqorg/coq:8.8"  SHOULD_SUPPORT="true"
      - COQ_IMAGE="coqorg/coq:8.9"  SHOULD_SUPPORT="true"
      - COQ_IMAGE="coqorg/coq:8.10" SHOULD_SUPPORT="true"

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
        opam pin add ${PACKAGE_NAME} . --kind=path --no-action -y
        opam config list; opam repo list; opam pin list; opam list
        " install

    script:
    - echo -e "${ANSI_YELLOW}Building...${ANSI_RESET}" && echo -en 'travis_fold:start:script\\r'
    - |
      docker exec COQ /bin/bash --login -c "
        export PS4='+ \e[33;1m(\$0 @ line \$LINENO) \$\e[0m '
        set -ex
        sudo chown -R coq:coq /home/project
        # Check if the package is compatible with the current environment
        if [ "${SHOULD_SUPPORT}" = "true" ] || opam install ${PACKAGE_NAME} --show-action -y; then
          # First install the dependencies
          opam install ${PACKAGE_NAME} --deps-only -y
          opam list
          # Then install the package itself in verbose mode
          opam install ${PACKAGE_NAME} -v -y
        fi;
        " script
    - echo -en 'travis_fold:end:script\\r'

    after_script:
    - docker stop COQ  # optional

This YAML file explains to&nbsp;Travis&nbsp;CI what to do to check the project. We use the [coqorg/coq](https://hub.docker.com/r/coqorg/coq) Docker images. These images have pre-compiled versions of Coq with opam, what is crucial to speedup the tests. For each architecture from Coq `8.4` to Coq `8.9` we:

* check if either:
  * the platform is supposed to be supported `if [ "${SHOULD_SUPPORT}" = "true" ]`,
  * or if opam considers the platform as compatible `opam install ${PACKAGE_NAME} --show-action -y`;
* install the dependencies `opam install ${PACKAGE_NAME} --deps-only -y`;
* install the project in verbose mode `opam install ${PACKAGE_NAME} -v -y`.

## Using Travis CI
You may need to activate Travis CI for your project in the [settings page of&nbsp;Travis&nbsp;CI](https://travis-ci.com/account/repositories). Then for each pull-request or commit you will see a green or red mark precising if the project passed the tests, along with detailed logs when you click on it:

![Commits in a pull-request](static/images/travis-ci/pull-request.png "Commits in a pull-request")

![Error logs](static/images/travis-ci/error-logs.png "Error logs")

Thanks for reading!
