#!/bin/bash

set -e

# Optional: Import test library
source dev-container-features-test-lib

check "flutter-exists" bash -c "ls /opt/flutter"
# TODO: add more checks, like correct channel or flutter/bin in path

# Report result
reportResults