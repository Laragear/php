#!/usr/bin/env bash

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
  echo "PHP_VERSION is already set to: ${PHP_VERSION}" > /dev/stdout
fi

apt-get install -y \
      php${PHP_VERSION}-cli \
      php${PHP_VERSION}-dev \
      php${PHP_VERSION}-pgsql \
      php${PHP_VERSION}-sqlite3  \
      php${PHP_VERSION}-gd \
      php${PHP_VERSION}-imagick \
      php${PHP_VERSION}-curl \
      php${PHP_VERSION}-memcached \
      php${PHP_VERSION}-mongodb \
      php${PHP_VERSION}-imap \
      php${PHP_VERSION}-mysql  \
      php${PHP_VERSION}-mbstring \
      php${PHP_VERSION}-xml \
      php${PHP_VERSION}-zip  \
      php${PHP_VERSION}-bcmath \
      php${PHP_VERSION}-soap \
      php${PHP_VERSION}-intl \
      php${PHP_VERSION}-readline  \
      php${PHP_VERSION}-pcov \
      php${PHP_VERSION}-msgpack \
      php${PHP_VERSION}-igbinary  \
      php${PHP_VERSION}-ldap \
      php${PHP_VERSION}-redis \
      php${PHP_VERSION}-xdebug

# Because Swoole usually is not immediately available when a new PHP version releases,
# we will check programatically if the the package exists, and it can be installed.
# If not, we will tell the developer that is not available for this PHP version.

SWOOLE_PACKAGE="php${PHP_VERSION}-swoole"

# Check if the package is available
if apt-cache show "$SWOOLE_PACKAGE" &>/dev/null; then
    echo "Package $SWOOLE_PACKAGE is available." > /dev/stdout

    # Check if the package is installable
    if sudo apt-get install -s "$SWOOLE_PACKAGE" &>/dev/null; then
        echo "Package $SWOOLE_PACKAGE is installable. Proceeding with installation." > /dev/stdout
        apt-get install "$SWOOLE_PACKAGE"
    else
        echo "Package $SWOOLE_PACKAGE is not installable for $PHP_VERSION." > /dev/stdout
    fi
else
    echo "Package $SWOOLE_PACKAGE is not available for $PHP_VERSION." > /dev/stdout
fi

# Allow PHP to run on lower-end ports
setcap "cap_net_bind_service=+ep" "/usr/bin/php${PHP_VERSION}"
