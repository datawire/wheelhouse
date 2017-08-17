#!/bin/bash
set -e -x

# Install any required system packages here:
#yum install -y ...

cd /io

# Compile wheels
for PYBIN in $(ls -d /opt/python/*/bin | fgrep cp27); do
    travis/build-wheels.sh "${PYBIN}/pip"
done

# Bundle external shared libraries into the wheels
for whl in $(ls wheelhouse/*.whl | fgrep -v none-any.whl); do
    auditwheel repair "$whl" -w wheelhouse
    rm "$whl"
done
