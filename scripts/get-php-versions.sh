#!/bin/bash

# Function to extract the major version
extract_major_version() {
  version="$1"
  echo "$version" | cut -d. -f1
}

# Function to extract the minor version
extract_minor_version() {
  version="$1"
  echo "$version" | cut -d. -f2 || "0"
}

# Function to compare versions
compare_versions() {
  # Normalize versions
  local version1=$(echo "$1" | awk -F. '{ print $1"."($2?$2:0)"."($3?$3:0) }')
  local version2=$(echo "$2" | awk -F. '{ print $1"."($2?$2:0)"."($3?$3:0) }')

  # Split versions into components
  IFS='.' read -r -a v1 <<< "$version1"
  IFS='.' read -r -a v2 <<< "$version2"

  # Compare each component
  for i in {0..2}; do
    if (( v1[i] < v2[i] )); then
      return 0 # version1 is less than version2
    elif (( v1[i] > v2[i] )); then
      return 1 # version1 is greater than or equal to version2
    fi
  done

  return 1 # versions are equal
}

PHP_VERSIONS_FILE=${PHP_VERSIONS_FILE:-"./conf/versions.yml"}
PHP_VERSION_MIN=${PHP_VERSION_MIN:-"5.6"}

# Ensure the directory exists
mkdir -p ./conf

rm -f "$PHP_VERSIONS_FILE"

# Fetch the JSON data from the URL
json_data=$(curl -s https://www.php.net/releases/index.php?json)

# Extract and filter the major versions using jq
filtered_versions=$( \
    echo "$json_data" | \
    jq -r \
        "to_entries | map(select(.key | tonumber)) | .[].value.version" | \
    sort -V  | \
    sed 's/[^0-9]/ /g' | \
    awk '{ print $1"."($2?$2:0)"."($3?$3:0) }'
)

echo $filtered_versions

for version in $filtered_versions; do
    major=$(extract_major_version "$version")
    latest_minor=$(extract_minor_version "$version")

    for ((minor=0; minor<=latest_minor; minor++)); do
        # Do not go below the minimum version
        if compare_versions "$major.$minor" "$PHP_VERSION_MIN"; then
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
        echo "- '$full_version'" >> $PHP_VERSIONS_FILE
    done
done
