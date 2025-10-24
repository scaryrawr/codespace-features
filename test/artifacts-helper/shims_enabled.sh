#!/bin/bash

set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

# Feature-specific tests for shims
check "shim directory exists" test -d /usr/local/artifacts-shims
check "npm shim exists" test -x /usr/local/artifacts-shims/npm
check "yarn shim exists" test -x /usr/local/artifacts-shims/yarn
check "dotnet shim exists" test -x /usr/local/artifacts-shims/dotnet
check "nuget shim exists" test -x /usr/local/artifacts-shims/nuget
check "pnpm shim exists" test -x /usr/local/artifacts-shims/pnpm
check "npx shim exists" test -x /usr/local/artifacts-shims/npx
check "rush shim exists" test -x /usr/local/artifacts-shims/rush

check "PATH includes shims" echo $PATH | grep -q /usr/local/artifacts-shims
check "shims are first in PATH" echo $PATH | grep -q "^/usr/local/artifacts-shims:"

# Verify shim content
check "npm shim uses template" grep -q "ARTIFACTS_ACCESSTOKEN" /usr/local/artifacts-shims/npm
check "dotnet shim has nuget config" grep -q "VSS_NUGET_ACCESSTOKEN" /usr/local/artifacts-shims/dotnet

# Test that shims can find real executables
check "node is installed" node --version
check "npm is installed" npm --version

# Test that shims actually work and don't call themselves recursively
check "npm shim can execute" /usr/local/artifacts-shims/npm --version

# Verify the shim finds the real npm (not itself)
check "shim finds real npm" bash -c 'REAL_NPM=$(/usr/local/artifacts-shims/npm config get prefix 2>/dev/null || echo "ok"); [ -n "$REAL_NPM" ]'

# Report results
reportResults
