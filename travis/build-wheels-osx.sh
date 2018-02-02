#!/bin/bash
set -e -x

# Compile wheels

for PYV in 2.7.14 3.3.7 3.4.7 3.5.4 3.6.4; do
    pyenv install ${PYV}
    pyenv global ${PYV}
    pip install wheel
    travis/build-wheels.sh pip python
done

# We build the generic stuff on linux
rm wheelhouse/*-none-any.whl
