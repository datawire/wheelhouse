#!/bin/bash
set -e -x

# Install a system package required by our library
#yum install -y atlas-devel

WHL_DIR = "/io/wheelhouse/$TRAVIS_OS_NAME"

# Compile wheels
for PYBIN in /opt/python/*/bin; do
#    "${PYBIN}/pip" install -r /io/dev-requirements.txt
    "${PYBIN}/pip" wheel -r /io/requirements.txt -w "$WHL_DIR"
done

# Bundle external shared libraries into the wheels
for whl in $WHL_DIR/*.whl; do
    auditwheel repair "$whl" -w "$WHL_DIR"
done

# Install packages and test
for PYBIN in /opt/python/*/bin/; do
    "${PYBIN}/pip" install python-manylinux-demo --no-index -f "$WHL_DIR"
    (cd "$HOME"; "${PYBIN}/nosetests" pymanylinuxdemo)
done
