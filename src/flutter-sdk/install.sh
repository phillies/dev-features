#!/usr/bin/env bash

# Checking if remote user is set, otherwise use "automatic" user
USERNAME="${USERNAME:-"${_REMOTE_USER:-"automatic"}"}"

set -e

echo "Activating feature 'flutter'"
echo "The chosen flutter SDK channel is: ${CHANNEL}"

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

# Install git
check_packages git ca-certificates


# Installing flutter into /opt
if [ ! -d "/opt/" ]; then
    mkdir /opt
fi
cd /opt
chmod a+rwX /opt

# failsafe if channel is not set, we use stable channel
if [ "${CHANNEL}" = "" ]; then
    CHANNEL=stable
fi

# cloning as user to avoid permission issues when updating flutter and installing dependencies
echo "Cloning flutter with channel $CHANNEL"
su ${USERNAME} -c "git clone --branch $CHANNEL https://github.com/flutter/flutter.git"
su ${USERNAME} -c "/opt/flutter/bin/flutter doctor"


# Add FLUTTER_HOME and bin directory into bashrc/zshrc files (unless disabled)
echo "Adding flutter to PATH"
updaterc "$(cat << EOF
export FLUTTER_HOME=/opt/flutter
if [[ "\${PATH}" != *"\${FLUTTER_HOME}/bin"* ]]; then export PATH="\${FLUTTER_HOME}/bin:\${PATH}"; fi
EOF
)"

# Clean up
rm -rf /var/lib/apt/lists/*

echo "Done!"