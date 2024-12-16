#!/usr/bin/env bash

# Retrieves the latest version number from PostgreSQL FTP over HTTP
get_latest_version() {
  curl -s https://ftp.postgresql.org/pub/latest/ | grep -oP 'postgresql-\d+\.\d+' | cut -d'-' -f2 | cut -d'.' -f1 | head -n 1
}

# Check if PGSQL_VERSION is empty or set to "latest"
if [ -z "$PGSQL_VERSION" ] || [ "$PGSQL_VERSION" == "latest" ]; then
  PGSQL_VERSION=$(get_latest_version "current")
  export PGSQL_VERSION
  echo "PGSQL_VERSION is set to the latest stable version: $PGSQL_VERSION" > /dev/stdout
else
  echo "PGSQL_VERSION is already set to: $PGSQL_VERSION" > /dev/stdout
fi

apt-get install -y postgresql-client-${PGSQL_VERSION}
