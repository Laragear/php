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

# Break out on EOL Debian since barely anything will work except from Node, barely.
if grep -q "archive.debian.org" "/etc/apt/sources.list"; then
    echo "Database tools are not supported on EOL Debian $CURRENT_OS_CODENAME. Install them separately." > /dev/stdout
    exit 0
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
    # Function to get the latest stable MongoDB version for a given Debian codename
    MONGODB_BASE_URL="https://s3.amazonaws.com/repo.mongodb.org?list-type=2&prefix=apt/debian/dists/${MONGODB_BASE_URL}/${CURRENT_OS_CODENAME}/mongodb-org/&delimiter=/"

    MONGODB_XML=$(curl -fsSL "$MONGODB_BASE_URL") || { return 1; }

    VERSIONS=$(printf '%s' "$MONGODB_XML" |
        # Grab everything between <Prefix>…</Prefix>
        grep -oP '(?<=<Prefix>)[^<]+' |
        # Keep only the part that ends with a slash and looks like 4.x.y
        grep -E '[0-9]+\.[0-9]+\.{0,1}[0-9]*' |
        # Strip the trailing slash so we have just "4.2.16"
        sed 's:/$::' | rev | cut -d/ -f1 | rev
    )

    # Fetch the content of the URL
    MONGODB_VERSION=$(printf '%s\n' "$VERSIONS" | sort -V | tail -n1)

    if [ ! -z "$MONGODB_VERSION" ]; then
        export MONGODB_VERSION
        echo "MONGODB_VERSION is set to the latest stable version: $MONGODB_VERSION" > /dev/stdout
    else
        echo "MONGODB_VERSION not found for ${CURRENT_OS_CODENAME}"
    fi

else
    echo "MONGODB_VERSION is already set to: $MONGODB_VERSION" > /dev/stdout
fi

# Ensure the keyrings directory exists
echo "Ensuring keyrings directory exists" > /dev/stdout
mkdir -p /etc/apt/keyrings

PACKAGES=sqlite3

# Node Repository
echo "Adding Node Repository" > /dev/stdout
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/node.gpg
echo "deb [signed-by=/etc/apt/keyrings/node.gpg] http://deb.nodesource.com/node_${NODE_VERSION}.x nodistro main" > /etc/apt/sources.list.d/node.list

# MySQL Repository
# Find if there is a distro version available for MySQL. If not, bail out.
if curl -s --head "https://repo.mysql.com/apt/debian/dists/{$CURRENT_OS_CODENAME}/" | grep "200 OK" > /dev/null; then
    echo "Adding MySQL Repository" > /dev/stdout
    curl -fsSL https://repo.mysql.com/RPM-GPG-KEY-mysql-2023 | gpg --dearmor -o /usr/share/keyrings/mysql.gpg
    echo "deb [signed-by=/usr/share/keyrings/mysql.gpg] http://repo.mysql.com/apt/debian/ ${CURRENT_OS_CODENAME} mysql-${MYSQL_REPO_VERSION}" > /etc/apt/sources.list.d/mysql.list
    PACKAGES="${PACKAGES:+PACKAGES }mysql-shell"
else
    echo "No repository for ${CURRENT_OS_CODENAME} for MariaDB ${MYSQL_VERSION}, not using MySQL client."
fi

# MariaDB Repository
# Find if there the distro version is available for MariaDB. If not, bail out.
if curl -s --head "http://mirror.mariadb.org/repo/${MARIADB_VERSION}/debian/dists/${CURRENT_OS_CODENAME}/" | grep "200 OK" > /dev/null; then
    echo "Adding MariaDB Repository" > /dev/stdout
    curl -fsSL https://mariadb.org/mariadb_release_signing_key.pgp | gpg --dearmor -o /usr/share/keyrings/mariadb.gpg
    echo "deb [signed-by=/usr/share/keyrings/mariadb.gpg] http://deb.mariadb.org/${MARIADB_VERSION}/debian ${CURRENT_OS_CODENAME} main" > /etc/apt/sources.list.d/mariadb.list
    PACKAGES="${PACKAGES:+PACKAGES }mariadb-client"
else
    echo "No repository for ${CURRENT_OS_CODENAME} for MariaDB ${MARIADB_VERSION}, not using MariaDB client."
fi

POSTGRESQL_CLIENT="postgresql-client"

# If the {CODENAME} repository exists, add it.
if curl -s --head "http://apt.postgresql.org/pub/repos/apt/dists/${CURRENT_OS_CODENAME}-pgdg" | grep "200 OK" > /dev/null; then
    # PostgreSQL Repository
    echo "Adding PostgreSQL Repository" > /dev/stdout
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/pgdg.gpg
    echo "deb [signed-by=/usr/share/keyrings/pgdg.gpg] http://apt.postgresql.org/pub/repos/apt ${CURRENT_OS_CODENAME}-pgdg main" > /etc/apt/sources.list.d/pgdg.list

    POSTGRESQL_CLIENT="postgresql-client-$PGSQL_VERSION"
    export POSTGRESQL_CLIENT
else
    echo "No repository for ${CURRENT_OS_CODENAME} for PostgreSQL, using default upstream client."
fi

PACKAGES="${PACKAGES:+PACKAGES }$POSTGRESQL_CLIENT"

# MongoDB Repository
if [ -z "$MONGODB_VERSION" ]; then
    echo "No MongoDB version found for ${CURRENT_OS_CODENAME}, nothing to add."
else
    echo "Adding MongoDB Repository" > /dev/stdout
    curl -fsSL https://www.mongodb.org/static/pgp/server-${MONGODB_VERSION}.asc | gpg --dearmor -o /usr/share/keyrings/mongodb.gpg
    echo "deb [signed-by=/usr/share/keyrings/mongodb.gpg] http://repo.mongodb.org/apt/debian ${CURRENT_OS_CODENAME}/mongodb-org/${MONGODB_VERSION} main" > /etc/apt/sources.list.d/mongodb.list
    PACKAGES="${PACKAGES:+PACKAGES }mongocli"
fi

echo "Installing Database Clients: $PACKAGES" > /dev/stdout

# Update APT with the new repositories
apt-get update

# Install the Database clients
apt-get install -y --no-install-recommends "$PACKAGES"

# Clean installation leftovers
apt-get -y autoremove
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
