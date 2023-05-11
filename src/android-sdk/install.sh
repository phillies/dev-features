#!/usr/bin/env bash

# Checking if remote user is set, otherwise use "automatic" user
USERNAME="${USERNAME:-"${_REMOTE_USER:-"automatic"}"}"
UPDATE_RC="true"

set -e

echo "Activating feature 'android-sdk'"
echo "The chosen android SDK platform is: ${PLATFORM}"

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
        if [[ "$(cat /etc/bash.bashrc)" != *"$1"* ]]; then
            echo -e "$1" >> /etc/bash.bashrc
        fi
        if [ -f "/etc/zsh/zshrc" ] && [[ "$(cat /etc/zsh/zshrc)" != *"$1"* ]]; then
            echo -e "$1" >> /etc/zsh/zshrc
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
check_packages unzip openjdk-11-jre


# Installing flutter into /opt
if [ ! -d "/opt/" ]; then
    mkdir /opt
fi
cd /opt
chmod a+rwX /opt

# installing latest command line tools
wget -nv https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip
unzip -q commandlinetools-linux-9477386_latest.zip -d /tmp


# failsafe if channel is not set, we use stable channel
if [ "${PLATFORM}" = "" ]; then
    PLATFORM="33"
fi

# regex which should find the last occurence: build-tools;33[^\s\t]+(?![\s\S]*build-tools;33)
# the "'!'" syntax is necessary because ! is not valid in a "" string but variables are not resolved in a '' string
# TODO: check for RC and make user choose via variable if they want to use rc versions
PLATFORM_REGEX="build-tools;$PLATFORM[^\s\t]+(?"'!'"[\s\S]*build-tools;$PLATFORM)"
BUILD_TOOLS=`/tmp/cmdline-tools/bin/sdkmanager --list --sdk_root=/opt/android-sdk/ | grep -Po $PLATFORM_REGEX | tail -1`

# installing sdk and accepting all licenses
yes | /tmp/cmdline-tools/bin/sdkmanager --sdk_root=/opt/android-sdk/ "platform-tools" "platforms;android-$PLATFORM" "$BUILD_TOOLS" "cmdline-tools;latest"
yes | /opt/android-sdk/cmdline-tools/latest/bin/sdkmanager --licenses --sdk_root=/opt/android-sdk/

# clean up
rm -rf *.zip /tmp/cmdline-tools

# Add FLUTTER_HOME and bin directory into bashrc/zshrc files (unless disabled)
echo "Adding android sdk to PATH"
updaterc "$(cat << EOF
export ANDROID_HOME=/opt/android-sdk/
export ANDROID_PLATFORM=${PLATFORM}
if [[ "\${PATH}" != *"\${ANDROID_HOME}/cmdline-tools/latest/bin"* ]]; then export PATH="\${ANDROID_HOME}/cmdline-tools/latest/bin:\${PATH}"; fi
if [[ "\${PATH}" != *"\${ANDROID_HOME}/tools/bin"* ]]; then export PATH="\${ANDROID_HOME}/tools/bin:\${PATH}"; fi
if [[ "\${PATH}" != *"\${ANDROID_HOME}/tools"* ]]; then export PATH="\${ANDROID_HOME}/tools:\${PATH}"; fi
if [[ "\${PATH}" != *"\${ANDROID_HOME}/platform-tools"* ]]; then export PATH="\${ANDROID_HOME}/platform-tools:\${PATH}"; fi
EOF
)"

# Clean up
rm -rf /var/lib/apt/lists/*

echo "Done!"