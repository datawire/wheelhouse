#!/bin/bash
set -e -x


WHL_DIR="wheelhouse/$TRAVIS_OS_NAME"

# Compile wheels
pip wheel -r requirements.txt -w "$WHL_DIR"
