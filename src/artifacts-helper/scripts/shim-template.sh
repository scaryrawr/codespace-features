#!/bin/bash

# Universal shim for TOOL_NAME
# This script wraps the real executable with artifact authentication

# Find the real executable by removing the shim directory from PATH
SHIM_DIR="$(cd "$(dirname "$0")" && pwd)"
NEW_PATH=$(echo "$PATH" | tr ':' '\n' | grep -v "^${SHIM_DIR}$" | tr '\n' ':' | sed 's/:$//')

REAL_EXE=$(PATH="$NEW_PATH" command -v TOOL_NAME)

if [ -z "${REAL_EXE}" ]; then
  echo "Error: Could not find real TOOL_NAME executable" >&2
  exit 127
fi

# Execute the real command with ARTIFACTS_ACCESSTOKEN in environment
if [ -f "${HOME}/ado-auth-helper" ]; then
  ARTIFACTS_ACCESSTOKEN=$(${HOME}/ado-auth-helper get-access-token) exec "${REAL_EXE}" "$@"
else
  exec "${REAL_EXE}" "$@"
fi
