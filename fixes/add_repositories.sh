#!/usr/bin/env bash

# Retrieves the latest version number from Node.js API
get_latest_version() {
  curl -s https://nodejs.org/dist/index.json | jq -r "[.[] | select(.version | test(\"${version}\"))] | .[0].version" | sed -E 's/^v([0-9]+)\..*/\1/'
}

# Check if NODE_VERSION is empty or set to "latest"
if [ -z "$NODE_VERSION" ] || [ "$NODE_VERSION" == "latest" ] || [ "$NODE_VERSION" == "current" ]; then
  NODE_VERSION="$(get_latest_version "current")"
  echo "NODE_VERSION is set to the current version: $NODE_VERSION" > /dev/stdout
# Check if NODE_VERSION is equal to "lts"
elif [ "$NODE_VERSION" == "lts" ]; then
  NODE_VERSION="$(get_latest_version "lts")"
  echo "NODE_VERSION is set to the LTS version: $NODE_VERSION" > /dev/stdout
else
  echo "NODE_VERSION is already set to: $NODE_VERSION" > /dev/stdout
fi

# Ondrej PHP Repository
curl -sS 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x14aa40ec0831756756d7f66c4f4ea0aae5267a6c' | gpg --dearmor | tee /etc/apt/keyrings/ppa_ondrej_php.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/ppa_ondrej_php.gpg] https://ppa.launchpadcontent.net/ondrej/php/ubuntu noble main" > /etc/apt/sources.list.d/ppa_ondrej_php.list

# Node Repository
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_VERSION}.x nodistro main" > /etc/apt/sources.list.d/nodesource.list

# Yarn Repository
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | tee /usr/share/keyrings/yarnkey.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list

# PostgreSQL Repository
curl -sS https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | tee /usr/share/keyrings/pgdg.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/pgdg.gpg] http://apt.postgresql.org/pub/repos/apt noble-pgdg main" > /etc/apt/sources.list.d/pgdg.list
