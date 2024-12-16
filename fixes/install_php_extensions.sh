#!/usr/bin/env bash

# Check if the trimmed input is not empty
if [ -z "$PHP_EXTENSIONS" ]; then
  echo "No additional PHP extensions to install, skipping." > /dev/stdout
  exit 0
fi

# Retrieves the latest version number from PHP releases
get_latest_version() {
  curl -s https://www.php.net/releases/index.php | grep -oP 'PHP \K\d+\.\d+' | head -1
}

# Check if PHP_VERSION is empty or set to "latest"
if [ -z "${PHP_VERSION}" ] || [ "${PHP_VERSION}" == "latest" ]; then
  PHP_VERSION=$(get_latest_version "latest")
  export PHP_VERSION
  echo "PHP_VERSION is set to the latest stable version: ${PHP_VERSION}" > /dev/stdout
else
  echo "PHP_VERSION is already set to: ${PHP_VERSION}"
fi

# Install the new extensions
IFS=',' read -r -a array <<< "${PHP_EXTENSIONS}"
for i in "${!array[@]}"; do
  array[i]="php${PHP_VERSION}-$(echo "${array[i]}" | xargs)"
done

# Join array into a single string with spaces and run apt-get install
apt-get install "${array[@]}"
