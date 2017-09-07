#!/bin/bash
set -e -x

# Install any required system packages here:
#yum install -y ...

cd /io

# Compile wheels
for PYBIN in $(ls -d /opt/python/*/bin | fgrep -v cp26); do
    travis/build-wheels.sh "${PYBIN}/pip" "${PYBIN}/python"
done

# Bundle external shared libraries into the wheels
for whl in $(ls wheelhouse/*.whl | fgrep -v none-any.whl | fgrep -v manylinux1_); do
    auditwheel repair "$whl" -w wheelhouse
    rm "$whl"
done
