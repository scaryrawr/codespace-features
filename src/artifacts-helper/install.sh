#!/bin/bash

set -e

PREFIXES="${NUGETURIPREFIXES:-"https://pkgs.dev.azure.com/"}"
USENET6="${DOTNET6:-"false"}"
ALIAS_DOTNET="${DOTNETALIAS:-"true"}"
ALIAS_NUGET="${NUGETALIAS:-"true"}"
ALIAS_NPM="${NPMALIAS:-"true"}"
ALIAS_YARN="${YARNALIAS:-"true"}"
ALIAS_NPX="${NPXALIAS:-"true"}"
ALIAS_RUSH="${RUSHALIAS:-"true"}"
ALIAS_PNPM="${PNPMALIAS:-"true"}"
INSTALL_PIP_HELPER="${PYTHON:-"false"}"
COMMA_SEP_TARGET_FILES="${TARGETFILES:-"DEFAULT"}"
USE_SHIMS="${USESHIMS:-"false"}"

ALIASES_ARR=()

if [ "${ALIAS_DOTNET}" = "true" ]; then
    ALIASES_ARR+=('dotnet')
fi
if [ "${ALIAS_NUGET}" = "true" ]; then
    ALIASES_ARR+=('nuget')
fi
if [ "${ALIAS_NPM}" = "true" ]; then
    ALIASES_ARR+=('npm')
fi
if [ "${ALIAS_YARN}" = "true" ]; then
    ALIASES_ARR+=('yarn')
fi
if [ "${ALIAS_NPX}" = "true" ]; then
    ALIASES_ARR+=('npx')
fi
if [ "${ALIAS_RUSH}" = "true" ]; then
    ALIASES_ARR+=('rush')
    ALIASES_ARR+=('rush-pnpm')
fi
if [ "${ALIAS_PNPM}" = "true" ]; then
    ALIASES_ARR+=('pnpm')
    ALIASES_ARR+=('pnpx')
fi

# Source /etc/os-release to get OS info
. /etc/os-release

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

apt_get_update() {
    if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
        echo "Running apt-get update..."
        apt-get update -y
    fi
}

# Checks if packages are installed and installs them if not
check_packages() {
    if ! dpkg -s "$@" > /dev/null 2>&1; then
        apt_get_update
        apt-get -y install --no-install-recommends "$@"
        rm -rf /var/lib/apt/lists/*
    fi
}

export DEBIAN_FRONTEND=noninteractive

if [ "${ID}" = "mariner" ]; then
    tdnf install -y wget ca-certificates
    tdnf clean all
else
    check_packages wget ca-certificates
fi

# Change to the directory where this script is located
cd "$(dirname "$0")"

cp ./scripts/install-provider.sh /tmp
chmod +rx /tmp/install-provider.sh
cp ./scripts/install-python-keyring.sh /tmp
chmod +rx /tmp/install-python-keyring.sh

sed "s|REPLACE_WITH_AZURE_DEVOPS_NUGET_FEED_URL_PREFIX|${PREFIXES}|g" ./scripts/run-dotnet.sh > /usr/local/bin/run-dotnet.sh
chmod +rx /usr/local/bin/run-dotnet.sh
sed "s|REPLACE_WITH_AZURE_DEVOPS_NUGET_FEED_URL_PREFIX|${PREFIXES}|g" ./scripts/run-nuget.sh > /usr/local/bin/run-nuget.sh
chmod +rx /usr/local/bin/run-nuget.sh
cp ./scripts/run-npm.sh /usr/local/bin/run-npm.sh
chmod +rx /usr/local/bin/run-npm.sh
cp ./scripts/run-yarn.sh /usr/local/bin/run-yarn.sh
chmod +rx /usr/local/bin/run-yarn.sh
cp ./scripts/write-npm.sh /usr/local/bin/write-npm.sh
chmod +rx /usr/local/bin/write-npm.sh
cp ./scripts/run-npx.sh /usr/local/bin/run-npx.sh
chmod +rx /usr/local/bin/run-npx.sh

cp ./scripts/run-rush.sh /usr/local/bin/run-rush.sh
chmod +rx /usr/local/bin/run-rush.sh
cp ./scripts/run-rush-pnpm.sh /usr/local/bin/run-rush-pnpm.sh
chmod +rx /usr/local/bin/run-rush-pnpm.sh

cp ./scripts/run-pnpm.sh /usr/local/bin/run-pnpm.sh
chmod +rx /usr/local/bin/run-pnpm.sh
cp ./scripts/run-pnpx.sh /usr/local/bin/run-pnpx.sh
chmod +rx /usr/local/bin/run-pnpx.sh

if [ "${INSTALL_PIP_HELPER}" = "true" ]; then
    USER="${_REMOTE_USER}" /tmp/install-python-keyring.sh
    rm /tmp/install-python-keyring.sh
fi

INSTALL_WITH_SUDO="false"
if command -v sudo >/dev/null 2>&1; then
    if [ "root" != "$_REMOTE_USER" ]; then
        INSTALL_WITH_SUDO="true"
    fi
fi

if [ "${COMMA_SEP_TARGET_FILES}" = "DEFAULT" ]; then
    if [ "${INSTALL_WITH_SUDO}" = "true" ]; then
        COMMA_SEP_TARGET_FILES="~/.bashrc,~/.zshrc"
    else
        COMMA_SEP_TARGET_FILES="/etc/bash.bashrc,/etc/zsh/zshrc"
    fi
fi

if [ "${USE_SHIMS}" = "true" ]; then
    # Create shim directory early in PATH
    SHIM_DIR="/usr/local/artifacts-shims"
    mkdir -p "${SHIM_DIR}"
    
    for ALIAS in "${ALIASES_ARR[@]}"; do
        if [ "${ALIAS}" = "dotnet" ] || [ "${ALIAS}" = "nuget" ]; then
            # Use dedicated shim scripts for dotnet/nuget
            sed "s|REPLACE_WITH_AZURE_DEVOPS_NUGET_FEED_URL_PREFIX|${PREFIXES}|g" ./scripts/shim-${ALIAS}.sh > "${SHIM_DIR}/${ALIAS}"
        else
            # Use template for other tools
            sed "s|TOOL_NAME|${ALIAS}|g" ./scripts/shim-template.sh > "${SHIM_DIR}/${ALIAS}"
        fi
        chmod +x "${SHIM_DIR}/${ALIAS}"
    done
    
    # Add shim directory to PATH for all users
    echo "export PATH=\"${SHIM_DIR}:\${PATH}\"" > /etc/profile.d/artifacts-shims.sh
    chmod +x /etc/profile.d/artifacts-shims.sh
else
    # Legacy: Use shell functions
    IFS=',' read -r -a TARGET_FILES_ARR <<< "$COMMA_SEP_TARGET_FILES"

    for ALIAS in "${ALIASES_ARR[@]}"; do
        for TARGET_FILE in "${TARGET_FILES_ARR[@]}"; do
            CMD="$ALIAS() { /usr/local/bin/run-$ALIAS.sh \"\$@\"; }"

            if [ "${INSTALL_WITH_SUDO}" = "true" ]; then
                sudo -u ${_REMOTE_USER} bash -c "echo '$CMD' >> $TARGET_FILE"
            else
                echo $CMD >> $TARGET_FILE || true
            fi
        done
    done
fi

if [ "${INSTALL_WITH_SUDO}" = "true" ]; then
    sudo -u ${_REMOTE_USER} bash -c "/tmp/install-provider.sh ${USENET6}"
fi
rm /tmp/install-provider.sh

exit 0