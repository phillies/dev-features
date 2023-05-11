#!/bin/bash

set -e

# Optional: Import test library
source dev-container-features-test-lib

check "android-exists" bash -c "ls /opt/android-sdk"
# TODO: add more checks, like path correct

# Report result
reportResults