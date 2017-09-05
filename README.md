# Wheelhouse

The wheelhouse project makes it fast and easy to build self contained
cross platform python executables that are installable with a single
`curl` command.

Now you might be thinking: wait, python is a scripting language, isn't
it already cross platform?

While this is true, there are still a host of obstacles when it comes
to building a single self contained executable:

1. Even simple python scripts often depend on third party dependencies
   making it necessary to "bundle" these dependencies somehow in order
   to create a self contained executable.

2. Many widely used python libraries depend on native code. When you
   do a `pip install` this code will often get compiled from
   source. If you want to distribute something `curl`able, you will
   need prebuilt wheels for every platform you are targeting.

Now you might be tempted to avoid these issues by giving up on `curl`
and using virtualenv as the basis for an installer, but there several
problems with this approach:

1. Using virtualenv in your installer places more requirements on your
   target users.

2. Virtualenvs sometimes break. (I know *you* pin your dependencies,
   but does everyone else that you transitively depend on pin their
   dependencies?)

It turns out we can solve all these problems by gluing together a
number of existing tools:

1. pex
2. manylinux
3. travis-ci.org
4. Amazon S3

Let's take a look at what each of these tools can do for us.

## How wheelhouse works

### Pex for bundling

Pex takes advantage of the python's ability to directly execute zip
archives in order to turn any set of python packages into a single
self contained executable. It can even bundle wheels for different
platforms and/or interpreters so you can make your self contained
executable cross platform as well.

There is a catch though. For this to work you need binary wheels for
all the platforms you want to target, and for many libraries, these
wheels simply don't exist. This is not a problem for people consuming
them via `pip install` as they are simply compiled at install time,
but this presents an obstacle for building our `curl` friendly pex. It
means we need to somehow build binaries for all our target platforms.

### Manylinux for portable linux wheels

Due to the obscure magic and mystery of dynamic linking, building
portable binaries for linux is actually a bit of a black art. This
could present a big problem if we have a python package that includes
native code. Luckily, however, the manylinux project was created
specificaly to address the issue of building native python packages in
a way that is portable to almost any linux you are likely to care
about.

They have created a special docker image with necessary environment
for creating these portable linux wheels, along with some tooling and
an [example travis
integration](https://github.com/pypa/python-manylinux-demo) to make
this easy.

### Travis-CI for mac wheels

While manylinux gives us portable linux binaries, we still need to
build osx wheels somehow. Luckily travis lets us run builds on macos,
and so we can extend the manylinux travis integration to also build
osx wheels.

### S3 for speed

But now we have another problem. Building all these permutations can
really start to slow down what should be a relatively quick and easy
python build, and adding in osx makes the problem significantly worse.

Travis-CI has very limited mac capacity to the point where a mac build
can easily spend 45 minutes in queue before it even starts, and if,
after queing for 45 minutes, it then runs your project's tests and
these fail, you can easily experience enough stress to lead to
premature balding and hypertension.

Fortunately, we can speed this up dramatically so long as your python
program itself doesn't have any native code. (It can still depend on
native packages as much as it wants to.) Instead of building all our
wheels directly in our own project's travis job, we can create a
separate travis job for the sole purpose of building all the native
linux and osx wheels necessary to create our standalone bundle. These
just need to be published somewhere (in this case S3) that your
project can access.

This is what the wheelhouse project is. A simple project that uses
travis to create a public archive with all the permutations of binary
wheels necessary to build cross platform python executables that use
any or all of the packages listed in
[requirements.txt](requirements.txt).

## Using wheelhouse

The shell script below illustrates how you would use the wheels built
by the wheelhouse project to create your own standalone python
executable. You can run the shell script locally and/or from within
your own travis project. The first time it runs it will sync all the
binary wheels from s3, but subsequent runs will be super fast.

```shell
#!/bin/bash
set -e

# This is boilerplate that finds the directory the script lives in and
# puts it in the DIR variable.

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

# REQUIRED CUSTOMIZATION:

# Set to the setuptools name for your project
PROJECT=my_project
# Set to the setuptools entrypoint for your binary
ENTRYPOINT=my_package:call_main
# Set to where you would like to save the pex binary
OUTPUT=dist/my-binary

# END REQUIRED_CUSTOMIZATION

# This assumes the script is in the project root. Change this if you
# move it into a subdirectory.
SRC_DIR=${DIR}

# The script will cache wheels here. Change this to whatever you want.
WHL_DIR=${DIR}/build/wheelhouse

# This will sync all various wheels (linux 32 bit, linux 64 bit, osx,
# etc) from S3 into a local directory so you can quickly build your
# cross platform python executable locally.
aws --no-sign-request s3 sync s3://datawire-static-files/wheelhouse $WHL_DIR

cd "${WHL_DIR}"

for whl in $(ls *-manylinux1_*.whl); do
  cp "${whl}" $(echo "${whl}" | sed s/manylinux1/linux/)
done

cd "${SRC_DIR}"

# This will package your python code up into a wheel.
pip wheel --no-index --no-deps . -w "${WHL_DIR}"

# This will use pex to assemble all the individual wheels (your
# project and all its dependencies) into a standalone cross platform
# executable.
pex --no-pypi -f "${WHL_DIR}" -r requirements.txt "${PROJECT}" -e "${ENTRYPOINT}" -o "${OUTPUT}" --disable-cache --platform linux_x86_64 --platform linux_i686 --platform macosx_10_11_x86_64
echo "Created ${OUTPUT}"
```

If you depend on something not already provided by wheelhouse, feel
free to file a pull request with an additional entry in
`requirements.txt`. If you want your own wheelhouse, just fork the
project and create your own archive of prebuilt binary wheels.
