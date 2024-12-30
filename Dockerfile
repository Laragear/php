ARG PHP_VERSION="latest"
ARG COMPOSER_VERSION="latest"
ARG FRANKENPHP_VERSION="latest"
ARG RR_VERSION="latest"
ARG NODE_VERSION="latest"
ARG DENO_VERSION="latest"
ARG BUN_VERSION="latest"
ARG S6_VERSION="latest"

FROM composer:${COMPOSER_VERSION} AS composer-image
FROM node:${NODE_VERSION} AS node-image
FROM dunglas/frankenphp:${FRANKENPHP_VERSION} AS frankenphp-image
FROM ghcr.io/roadrunner-server/roadrunner:${RR_VERSION} AS roadrunner-image
FROM denoland/deno:${DENO_VERSION} AS deno-image
FROM oven/bun:${BUN_VERSION} AS bun-image

FROM php:${PHP_VERSION}

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

ENV USER_PWD="developer"
ENV USER="developer"
ENV USER_ID=1000
ENV GROUP_ID=1000
ENV HOME="/home/$USER"
ENV PROJECT_PATH="/app"

ARG PHP_BASE_EXTENSIONS="opcache pcntl pdo_mysql pdo_pgsql mongodb redis zip swoole xdebug"
ARG PHP_EXTENSIONS=""
ENV PHP_RUNTIME_EXTENSIONS=""

ARG MYSQL_VERSION="latest"
ARG MARIADB_VERSION="latest"
ARG POSTGRESQL_VERSION="latest"
ARG MONGODB_VERSION="latest"

ENV COMPOSER_HOME="/composer"
ENV COMPOSER_CACHE_DIR="$COMPOSER_HOME/cache"
ENV COMPOSER_BIN_DIR="$COMPOSER_HOME/bin"

ENV PATH $PATH:$COMPOSER_BIN_DIR

ARG S6-VERSION="latest"

#
#--------------------------------------------------------------------------
# Default CLI interpreter
#--------------------------------------------------------------------------
#

SHELL ["/bin/bash", "-c"]

#
#--------------------------------------------------------------------------
# Common fixes
#--------------------------------------------------------------------------
#

# Fix APT for newer Debian > 10
RUN \
    DEBIAN_VERSION_MAJOR=$(cat /etc/debian_version | cut -d'.' -f1) && \
    if [ "$DEBIAN_VERSION_MAJOR" -gt 11 ]; then \
        echo "Acquire::http::Pipeline-Depth 0;" > /etc/apt/apt.conf.d/99custom && \
        echo "Acquire::http::No-Cache true;" >> /etc/apt/apt.conf.d/99custom && \
        echo "Acquire::BrokenProxy    true;" >> /etc/apt/apt.conf.d/99custom; \
    fi

#
#--------------------------------------------------------------------------
# Install from layers
#--------------------------------------------------------------------------
#
# We're going to install all these utilities to the "/usr/local/bin" path
# because this is the place for manually installed command utilities.
#

# The rest of the tools only need a single binary to be copied
COPY --from=frankenphp-image    /usr/local/bin/frankenphp   /usr/local/bin/frankenphp
COPY --from=roadrunner-image    /usr/bin/rr                 /usr/local/bin/rr
COPY --from=deno-image          /usr/bin/deno               /usr/local/bin/deno
COPY --from=bun-image           /usr/local/bin/bun          /usr/local/bin/bun
COPY --from=composer-image      /usr/bin/composer           /usr/local/bin/composer


#
#--------------------------------------------------------------------------
# Package Manager - Switch to reachable repository
#--------------------------------------------------------------------------
#

COPY ./fixes/set_old_repository.sh /var/fixes/set_old_repository.sh

RUN /var/fixes/set_old_repository.sh

#
#--------------------------------------------------------------------------
# Package Manager - Install Base Software
#--------------------------------------------------------------------------
#

RUN \
    echo "Setting base utilities for the container" > /dev/stdout && \
    apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
      curl \
      ca-certificates \
      dnsutils \
      ffmpeg \
      git \
      gnupg \
      gosu \
      htop \
      jq \
      libcap2-bin \
      libpng-dev \
      librsvg2-bin \
      lsb-release \
      nano \
      openssh-server \
      python3 \
      sudo \
      unzip \
      xz-utils \
      zip && \
    # Check if YQ is available. If not, don't install it. \
    if apt-get install --dry-run yq &> /dev/null; then \
      apt-get install -y --no-install-recommends yq; \
    fi && \
    # Check if FSWATCH is available. If not, don't install it. \
    if apt-get install --dry-run fswatch &> /dev/null; then \
      apt-get install -y --no-install-recommends fswatch; \
    fi && \
    # Clean installation leftovers
    apt-get -y autoremove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

#
#--------------------------------------------------------------------------
# Package Manager - Install Database CLI and Node via external repositories
#--------------------------------------------------------------------------
#

COPY ./fixes/install_repositories_and_packages.sh /var/fixes/install_repositories_and_packages.sh
RUN /var/fixes/install_repositories_and_packages.sh

#
#--------------------------------------------------------------------------
# Package Manager - Install PHP base Extensions
#--------------------------------------------------------------------------
#

# Add the PHP Extension installer
ADD --chmod=0755 https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

RUN \
    # Install PHP Extensions
    echo "Installing base PHP Extensions: $PHP_BASE_EXTENSIONS" > /dev/stdout && \
    install-php-extensions $PHP_BASE_EXTENSIONS

#
#--------------------------------------------------------------------------
# Package Manager - Complete Node Runtime install
#--------------------------------------------------------------------------
#

RUN \
    apt-get update && \
    # Install Node
    echo 'Installing Node' > /dev/stdout && \
    apt-get install -y --no-install-recommends nodejs && \
    # Enable Corepack
    if [ -f '/usr/bin/corepack' ]; then \
        echo 'Enabling Corepack' > /dev/stdout && \
        corepack enable && \
        # Enable NPM \
        echo 'Installing NPM via Corepack' > /dev/stdout && \
        corepack install --global npm && \
        # Enable Yarn
        echo 'Installing Yarn via Corepack' > /dev/stdout && \
        corepack install --global yarn && \
        # Yarn smoke test
        yarn -v && \
        # Enable PNPM
        echo 'Installing PNPM via Corepack' > /dev/stdout && \
        corepack install --global pnpm && \
        # PNPM smoke test
        pnpm -v; \
    else \
      echo 'This version of Debian does not support Node Corepack' > /dev/stdout; \
    fi && \
    # Clean installation leftovers
    apt-get -y autoremove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

#
#--------------------------------------------------------------------------
# Runtime Fixes
#--------------------------------------------------------------------------
#

# Ensure all runtimes have access to privileged ports belo 1024 (like 22, 80 or 443)
RUN \
    echo "Ensuring all runtimes have access to low-end port numbers" > /dev/stdout && \
    # Old Node sometimes installs itself has "nodejs", so use that if "node" doesn't exists.
    if [ -f /usr/bin/node ]; then \
      setcap "cap_net_bind_service=+ep" /usr/bin/node; \
    elif [ -f /usr/bin/nodejs ]; then \
      setcap "cap_net_bind_service=+ep" /usr/bin/nodejs; \
    fi && \
    setcap "cap_net_bind_service=+ep" /usr/sbin/sshd && \
    setcap "cap_net_bind_service=+ep" /usr/local/bin/rr && \
    setcap "cap_net_bind_service=+ep" /usr/local/bin/bun && \
    setcap "cap_net_bind_service=+ep" /usr/local/bin/php && \
    setcap "cap_net_bind_service=+ep" /usr/local/bin/deno && \
    setcap "cap_net_bind_service=+ep" /usr/local/bin/composer && \
    setcap "cap_net_bind_service=+ep" /usr/local/bin/frankenphp

#
#--------------------------------------------------------------------------
# Install S6 Overlay
#--------------------------------------------------------------------------
#
# @see https://github.com/just-containers/s6-overlay
#

COPY ./fixes/install_s6_overlay.sh /var/fixes/install_s6_overlay.sh
RUN /var/fixes/install_s6_overlay.sh

# Copy the S6 Configuration files to the container.
COPY etc /etc

# Set the entrypoint to S6 OVerlay custom INIT.
ENTRYPOINT ["/init"]

#
#--------------------------------------------------------------------------
# User - Configuration
#--------------------------------------------------------------------------
#

COPY ./fixes/set_user.sh /var/fixes/set_user.sh

RUN /var/fixes/set_user.sh

#
#--------------------------------------------------------------------------
# SSH - Configuration
#--------------------------------------------------------------------------
#

RUN \
    echo "Ensuring SSH directory can be accessed by ${USER}" > /dev/stdout && \
    # Ensure SSH directories are permissive
    mkdir -p /ssh/sshd_config /ssh/sshd_keys && \
    # Copy the SSH keys generated by OpenSSH Server
    cp /etc/ssh/ssh_host_{rsa,ecdsa,ed25519}_key /ssh/sshd_keys/ && \
    chown -R ${USER_ID}:${GROUP_ID} /ssh && \
    mkdir -p /run/sshd

#
#--------------------------------------------------------------------------
# Project - Configuration
#--------------------------------------------------------------------------
#

COPY ./fixes/set_symlinks.sh /var/fixes/set_symlinks.sh

RUN /var/fixes/set_symlinks.sh

#
#--------------------------------------------------------------------------
# Add PHP Extensions
#--------------------------------------------------------------------------
#
# We are going to install all the developer's PHP extensions as the last
# step. This will avoid running previous layers again, which will add
# to the build time, if an extension installation throws an error.
#

RUN \
    echo "Installing additional PHP Extensions: $PHP_EXTENSIONS" > /dev/stdout && \
    install-php-extensions $PHP_EXTENSIONS

#
#--------------------------------------------------------------------------
# Configure Composer
#--------------------------------------------------------------------------
#
# Ensure the Composer directories exists and are accessible.
RUN \
    echo "Ensure Composer directory is '$COMPOSER_HOME' and the cache is '$COMPOSER_CACHE_DIR'" > /dev/stdout && \
    mkdir ${COMPOSER_HOME} ${COMPOSER_CACHE_DIR} && \
    chown ${USER_ID}:${GROUP_ID} -R /composer

# If we're using Composer on a non-supported PHP version, downgrade to LTS.
RUN \
    if ! composer show --platform | grep -q $(php -r "echo 'PHP version: ' . phpversion();"); then \
        echo "Composer doesn't support this PHP version, downgrading to 2.2 (LTS)." > /dev/stdout && \
        composer self-update --2.2; \
    fi



# Let's also add some common composer utilities globally.
RUN \
    echo "Adding some useful Composer packages globally" > /dev/stdout && \
    sudo -u $USER /usr/local/bin/composer --no-cache global require \
      laravel/pint \
      phpunit/phpunit && \
    # Clear composer cache and keep the image size lean
    composer clear-cache

#
#--------------------------------------------------------------------------
# Common fixes
#--------------------------------------------------------------------------
#

RUN \
    echo "Setting the container timezone to '$TZ'" > /dev/stdout && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

#
#--------------------------------------------------------------------------
# Make the container ready to use
#--------------------------------------------------------------------------
#

WORKDIR /app

# Set the entrypoint to S6 OVerlay custom INIT.
ENTRYPOINT ["/init"]

CMD ["/bin/bash"]
