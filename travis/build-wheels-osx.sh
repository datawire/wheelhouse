#!/bin/bash
set -e -x

# Compile wheels
travis/build-wheels.sh pip

# We build the generic stuff on linux
rm wheelhouse/*-none-any.whl
