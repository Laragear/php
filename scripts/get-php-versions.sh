#!/bin/bash

# Function to extract the major version
extract_major_version() {
  version="$1"
  echo "$version" | cut -d. -f1
}

# Function to extract the minor version
extract_minor_version() {
  version="$1"
  echo "$version" | cut -d. -f2
}

PHP_FILE_VERSIONS="./conf/versions.yaml"

# Fetch the JSON data from the URL
json_data=$(curl -s https://www.php.net/releases/index.php?json)

# Extract and filter the major versions using jq
filtered_versions=$(echo "$json_data" | jq -r 'to_entries | map(select(.key | tonumber >= 7)) | .[].value.version' | sort -V)

# Create a very simple YAML where each version will be set
echo "versions:" > $PHP_FILE_VERSIONS

for version in $filtered_versions; do
    major=$(extract_major_version "$version")
    latest_minor=$(extract_minor_version "$version")

    for ((minor=0; minor<=latest_minor; minor++)); do
        # Do not go below v7.0
        if [[ "$major" -lt 7 ]]; then
            continue
        fi

        full_version="$major.$minor"

        if [ "$USE_FULL_VERSION" == "true" ]; then
            echo "Checking for PHP $major.$minor"

            # Query the URL for the version data
            version_data=$(curl -s "https://www.php.net/releases/index.php?json&version=$major.$minor")

            # Extract the version key value
            version_value=$(echo "$version_data" | jq -r '.version')

            echo "Latest version for $major.$minor is $version_value"

            # Add the version value to the array
            full_version="$version_value"
        fi

         # Add the version to the list
        echo "  - $full_version" >> $PHP_FILE_VERSIONS
    done
done
