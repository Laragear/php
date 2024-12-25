#!/usr/bin/env bash

# Retrieves the latest version number from Node.js API
get_node_version() {
  curl -s https://nodejs.org/dist/index.json | jq -r "[.[] | select(.version | test(\"${version}\"))] | .[0].version" | sed -E 's/^v([0-9]+)\..*/\1/'
}

# Find the current container system architecture
case $(uname -m) in
    aarch64 ) export ARCH='aarch64' ;;
    arm64   ) export ARCH='aarch64' ;;
    armhf   ) export ARCH='armhf'   ;;
    arm*    ) export ARCH='arm'     ;;
    i4*     ) export ARCH='i486'    ;;
    i6*     ) export ARCH='i686'    ;;
    s390*   ) export ARCH='s390x'   ;;
    *       ) export ARCH='x86_64'  ;;
esac

CURRENT_OS_CODENAME="$(lsb_release -cs)"

echo "Adding repositories" > /dev/stdout

# Check if NODE_VERSION is empty or set to "latest"
if [ -z "$NODE_VERSION" ] || [ "$NODE_VERSION" == "latest" ] || [ "$NODE_VERSION" == "current" ]; then
  NODE_VERSION="$(get_node_version "current")"
  echo "NODE_VERSION is set to the current version: $NODE_VERSION" > /dev/stdout
# Check if NODE_VERSION is equal to "lts"
elif [ "$NODE_VERSION" == "lts" ]; then
  NODE_VERSION="$(get_node_version "lts")"
  echo "NODE_VERSION is set to the LTS version: $NODE_VERSION" > /dev/stdout
else
  echo "NODE_VERSION is already set to: $NODE_VERSION" > /dev/stdout
fi

MYSQL_REPO_VERSION="innovation"

# Check if MYSQL_VERSION is empty or set to "latest"
if [ -z "$MYSQL_VERSION" ] || [ "$MYSQL_VERSION" == "latest" ] || [ "$MYSQL_VERSION" == "innovation" ]; then
  # Fetch the URL content
  content=$(curl -s "http://repo.mysql.com/apt/debian/dists/$CURRENT_OS_CODENAME/")

  if echo "$content" | grep -q "innovation"; then
      MYSQL_REPO_VERSION="innovation"
  else
    MYSQL_VERSION=$(echo "$content" | grep -oP 'mysql-\d+\.\d+' | sort -V | tail -n 1)
    MYSQL_REPO_VERSION="$MYSQL_VERSION"
  fi

  export MYSQL_VERSION
  echo "MYSQL_VERSION is set to the latest stable version: $MYSQL_VERSION" > /dev/stdout
else
  echo "MYSQL_VERSION is already set to: $MYSQL_VERSION" > /dev/stdout
fi

# Check if MARIADB_VERSION is empty or set to "latest"
if [ -z "$MARIADB_VERSION" ] || [ "$MARIADB_VERSION" == "latest" ] || [ "$MARIADB_VERSION" == "stable" ]; then
  MARIADB_VERSION=$(curl -s https://downloads.mariadb.org/rest-api/mariadb/ | jq -r '.major_releases[] | select(.release_id | test("^[0-9]+\\.[0-9]+$")) | .release_id' | head -n 1)
  export MARIADB_VERSION
  echo "MARIADB_VERSION is set to the latest stable version: $MARIADB_VERSION" > /dev/stdout
else
  echo "MARIADB_VERSION is already set to: $MARIADB_VERSION" > /dev/stdout
fi

if [ -z "$PGSQL_VERSION" ] || [ "$PGSQL_VERSION" == "latest" ]; then
  PGSQL_VERSION=$(curl -s https://ftp.postgresql.org/pub/latest/ | grep -oP 'postgresql-\d+\.\d+' | cut -d'-' -f2 | cut -d'.' -f1 | head -n 1)
  export PGSQL_VERSION
  echo "PGSQL_VERSION is set to the latest stable version: $PGSQL_VERSION" > /dev/stdout
else
  echo "PGSQL_VERSION is already set to: $PGSQL_VERSION" > /dev/stdout
fi

# Check if MONGODB_VERSION is empty or set to "latest"
if [ -z "$MONGODB_VERSION" ] || [ "$MONGODB_VERSION" == "latest" ]; then
  # Fetch the content of the URL
  MONGODB_VERSION=$(
        curl -s "http://downloads.mongodb.org.s3.amazonaws.com/current.json" | jq -r ".versions[] | select(.development_release == false and (.downloads[] | select(.arch == \"$ARCH\" and (.target | startswith(\"debian\")) and (.packages[] | contains(\"$CURRENT_OS_CODENAME\") ) ))) | .version" | \
        sort -V | \
        tail -n 1 | \
        awk -F. '{print $1 "." $2}'
    )
  export MONGODB_VERSION
  echo "MONGODB_VERSION is set to the latest stable version: $MONGODB_VERSION" > /dev/stdout
else
  echo "MONGODB_VERSION is already set to: $MONGODB_VERSION" > /dev/stdout
fi

# Ensure the keyrings directory exists
echo "Ensuring keyrings directory exists" > /dev/stdout
mkdir -p /etc/apt/keyrings

# Node Repository
echo "Adding Node Repository" > /dev/stdout
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/node.gpg
echo "deb [signed-by=/etc/apt/keyrings/node.gpg] https://deb.nodesource.com/node_${NODE_VERSION}.x nodistro main" > /etc/apt/sources.list.d/node.list

# MySQL Repository
echo "Adding MySQL Repository" > /dev/stdout
curl -fsSL https://repo.mysql.com/RPM-GPG-KEY-mysql-2023 | gpg --dearmor -o /usr/share/keyrings/mysql.gpg
echo "deb [signed-by=/usr/share/keyrings/mysql.gpg] http://repo.mysql.com/apt/debian/ ${CURRENT_OS_CODENAME} mysql-${MYSQL_REPO_VERSION}" > /etc/apt/sources.list.d/mysql.list

# MariaDB Repository
echo "Adding MariaDB Repository" > /dev/stdout
curl -fsSL https://mariadb.org/mariadb_release_signing_key.pgp | gpg --dearmor -o /usr/share/keyrings/mariadb.gpg
echo "deb [signed-by=/usr/share/keyrings/mariadb.gpg] https://deb.mariadb.org/${MARIADB_VERSION}/debian ${CURRENT_OS_CODENAME} main" > /etc/apt/sources.list.d/mariadb.list

POSTGRESQL_CLIENT="postgresql-client"

# If the {CODENAME} repository exists, add it.
if curl -s --head "https://apt.postgresql.org/pub/repos/apt/dists/${CURRENT_OS_CODENAME}-pgdg" | grep "200 OK" > /dev/null; then
    # PostgreSQL Repository
    echo "Adding PostgreSQL Repository" > /dev/stdout
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/pgdg.gpg
    echo "deb [signed-by=/usr/share/keyrings/pgdg.gpg] http://apt.postgresql.org/pub/repos/apt ${CURRENT_OS_CODENAME}-pgdg main" > /etc/apt/sources.list.d/pgdg.list

    POSTGRESQL_CLIENT="postgresql-client-$PGSQL_VERSION"
    export POSTGRESQL_CLIENT
else
    echo "No repository for ${CURRENT_OS_CODENAME} for PostgreSQL, using default upstream client."
fi

# MongoDB Repository
echo "Adding MongoDB Repository" > /dev/stdout
curl -fsSL https://www.mongodb.org/static/pgp/server-${MONGODB_VERSION}.asc | gpg --dearmor -o /usr/share/keyrings/mongodb.gpg
echo "deb [signed-by=/usr/share/keyrings/mongodb.gpg] https://repo.mongodb.org/apt/debian ${CURRENT_OS_CODENAME}/mongodb-org/${MONGODB_VERSION} main" > /etc/apt/sources.list.d/mongodb.list

echo "Installing Database Clients" > /dev/stdout

# Update APT with the new repositories
apt-get update

# Install the Database clients
apt-get install -y --no-install-recommends \
    mysql-shell \
    mariadb-client \
    $POSTGRESQL_CLIENT \
    mongodb-atlas-cli \
    sqlite3

# Clean installation leftovers
apt-get -y autoremove
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
