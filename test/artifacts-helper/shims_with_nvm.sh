#!/bin/bash

set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

# Feature-specific tests for shims with nvm
check "shim directory exists" test -d /usr/local/artifacts-shims
check "npm shim exists" test -x /usr/local/artifacts-shims/npm
check "yarn shim exists" test -x /usr/local/artifacts-shims/yarn

check "PATH includes shims" echo $PATH | grep -q /usr/local/artifacts-shims

# Test that node/npm are installed via nvm
check "node is installed" node --version
check "npm is installed" npm --version

# Verify nvm is available
check "nvm is installed" bash -c '. /usr/local/share/nvm/nvm.sh && nvm --version'

# Test that the shim can find npm from nvm
check "shim finds npm" which npm
check "npm shim works" npm --version

# Verify the npm being called is from nvm's path (or at least works)
check "npm location check" bash -c 'NPM_PATH=$(which npm); echo "npm at: $NPM_PATH"; [ -n "$NPM_PATH" ]'

# Test that we can actually use npm through the shim
check "npm list works" npm list --depth=0 2>/dev/null || echo "No packages (expected)"

# Verify yarn also works
check "yarn is available" which yarn
check "yarn shim works" yarn --version

# Report results
reportResults
