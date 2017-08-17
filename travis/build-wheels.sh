#!/bin/bash
set -e -x

PIP="$1"

# Install any dev requirements
if [ -e dev-requirements.txt ]; then
    $PIP install -r dev-requirements.txt
fi

# Compile wheels
$PIP wheel -r requirements.txt -w wheelhouse
