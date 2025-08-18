#!/bin/bash

OUTPUT_FILE="conf/debian.yaml"
> "$OUTPUT_FILE"  # Clear file

# Get current timestamp
now_ts=$(date +%s)

# Fetch JSON and filter using Bash
curl -s https://endoflife.date/api/debian.json | jq -c '.[]' | while read -r line; do
  eol=$(echo "$line" | jq -r '.eol')
  if [[ "$eol" != "null" ]]; then
    eol_ts=$(date -d "$eol" +%s)
    if (( eol_ts > now_ts )); then
      codename=$(echo "$line" | jq -r '.codename' | tr '[:upper:]' '[:lower:]')
      version=$(echo "$line" | jq -r '.cycle')
      echo "  - name: \"$codename\"" >> "$OUTPUT_FILE"
      echo "    version: \"$version\"" >> "$OUTPUT_FILE"
    fi
  fi
done

# Wrap in YAML structure
sed -i '1s/^/versions:\n/' "$OUTPUT_FILE"

echo "YAML file created: $OUTPUT_FILE"
