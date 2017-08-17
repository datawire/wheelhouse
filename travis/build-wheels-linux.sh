#!/bin/bash
set -e -x

docker run --rm -v `pwd`:/io $DOCKER_IMAGE $PRE_CMD /io/travis/build-wheels-docker.sh
