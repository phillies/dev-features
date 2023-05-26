#!/usr/bin/env bash

# Checking if remote user is set, otherwise use "automatic" user
USERNAME="${USERNAME:-"${_REMOTE_USER:-"automatic"}"}"
UPDATE_RC="true"
FLUTTER_HOME="/opt/flutter"

set -e

echo "Activating feature 'flutter-sdk'"
echo "The chosen flutter SDK channel is: ${CHANNEL}"
echo "FLUTTER_HOME is ${FLUTTER_HOME}"

# Clean up
rm -rf /var/lib/apt/lists/*

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

# Determine the appropriate non-root user
if [ "${USERNAME}" = "auto" ] || [ "${USERNAME}" = "automatic" ]; then
    USERNAME=""
    POSSIBLE_USERS=("vscode" "node" "codespace" "$(awk -v val=1000 -F ":" '$3==val{print $1}' /etc/passwd)")
    for CURRENT_USER in "${POSSIBLE_USERS[@]}"; do
        if id -u ${CURRENT_USER} > /dev/null 2>&1; then
            USERNAME=${CURRENT_USER}
            break
        fi
    done
    if [ "${USERNAME}" = "" ]; then
        USERNAME=root
    fi    
fi

updaterc() {
    if [ "${UPDATE_RC}" = "true" ]; then
        echo "Updating /etc/bash.bashrc and /etc/zsh/zshrc..."
        if [ -f "/etc/bash.bashrc" ] && [[ "$(cat /etc/bash.bashrc)" != *"$1"* ]]; then
            echo -e "$1" >> /etc/bash.bashrc
            echo "/etc/bash.bashrc updated"
        fi
        if [ -f "/etc/bash/bashrc" ] && [[ "$(cat /etc/bash/bashrc)" != *"$1"* ]]; then
            echo -e "$1" >> /etc/bash/bashrc
            echo "/etc/bash/bashrc updated"
        fi        
        if [ -f "/etc/zsh/zshrc" ] && [[ "$(cat /etc/zsh/zshrc)" != *"$1"* ]]; then
            echo -e "$1" >> /etc/zsh/zshrc
            echo "/etc/zsh/zshrc updated"
        fi
    fi
}

apt_get_update()
{
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
    fi
}

# Ensure apt is in non-interactive to avoid prompts
export DEBIAN_FRONTEND=noninteractive

# Install flutter dependencies
check_packages clang cmake ninja-build libgtk-3-dev

# Clean up
rm -rf /var/lib/apt/lists/*

echo "Done!"
