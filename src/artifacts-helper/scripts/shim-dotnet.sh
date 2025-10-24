#!/bin/bash

# Shim for dotnet with artifact authentication

# Install artifact credential provider if it is not already installed
if [ ! -d "${HOME}/.nuget/plugins/netcore" ]; then
  wget -qO- https://aka.ms/install-artifacts-credprovider.sh | bash
fi

# Find the real executable by removing the shim directory from PATH
SHIM_DIR="$(cd "$(dirname "$0")" && pwd)"
NEW_PATH=$(echo "$PATH" | tr ':' '\n' | grep -v "^${SHIM_DIR}$" | tr '\n' ':' | sed 's/:$//')

REAL_EXE=$(PATH="$NEW_PATH" command -v dotnet)

if [ -z "${REAL_EXE}" ]; then
  echo "Error: Could not find real dotnet executable" >&2
  exit 127
fi

# Execute the real command with NuGet credentials in environment
if [ -f "${HOME}/ado-auth-helper" ]; then
  VSS_NUGET_ACCESSTOKEN=$(${HOME}/ado-auth-helper get-access-token) \
  VSS_NUGET_URI_PREFIXES=REPLACE_WITH_AZURE_DEVOPS_NUGET_FEED_URL_PREFIX \
  exec "${REAL_EXE}" "$@"
else
  exec "${REAL_EXE}" "$@"
fi
