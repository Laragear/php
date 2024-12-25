#!/bin/bash

# Find the current container system architecture
case $(uname -m) in
    aarch64 ) export S6_ARCH='aarch64' ;;
    arm64   ) export S6_ARCH='aarch64' ;;
    armhf   ) export S6_ARCH='armhf'   ;;
    arm*    ) export S6_ARCH='arm'     ;;
    i4*     ) export S6_ARCH='i486'    ;;
    i6*     ) export S6_ARCH='i686'    ;;
    s390*   ) export S6_ARCH='s390x'   ;;
    *       ) export S6_ARCH='x86_64'  ;;
esac

# If there was no version for S6 overlay, set it as the latest.
if [ -z "$S6_VERSION" ] || [ "$S6_VERSION" == "latest" ]; then
    # Fetch the latest release data from GitHub API
    latest_release=$(curl -s https://api.github.com/repos/just-containers/s6-overlay/releases/latest)

    # Extract the version tag from the JSON response (the first one is the latest) and set it as the version
    S6_VERSION=$(echo "$latest_release" | grep -oP '"tag_name": "\K(.*)(?=")')
fi

# Ensure the version number starts with "v" if it doesn't
if [[ "$S6_VERSION" != v* ]]; then
    S6_VERSION="v$S6_VERSION"
fi

# Fetch the release data for the version tag
RELEASE=$(curl -s "https://api.github.com/repos/just-containers/s6-overlay/releases/tags/${S6_VERSION}")

# Use jq to extract the download URL for the specified architecture
DOWNLOAD_URL=$(echo "$RELEASE" | jq -r --arg S6_ARCH "$S6_ARCH" '
    .assets[] | select(.name | contains($S6_ARCH) and endswith(".tar.xz")) | .browser_download_url
')

# Same as above, but for the core scripts.
SCRIPT_URL=$(echo "$RELEASE" | jq -r '
    .assets[] | select(.name == "s6-overlay-noarch.tar.xz") | .browser_download_url
')

# Smoke test
echo "Binaries to download: $DOWNLOAD_URL" > /dev/stdout
echo "Script to download: $SCRIPT_URL" > /dev/stdout
echo "Downloading S6 Overlay ${S6_VERSION} for ${S6_ARCH}" > /dev/stdout

# Actually install the damn thing
curl -sSL "$SCRIPT_URL" | tar -pxJ -C /
curl -sSL "$DOWNLOAD_URL" | tar -pxJ -C /
