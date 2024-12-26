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

ARG USER_PWD="dev"
ENV USER="dev"
ENV USER_ID=1000
ENV GROUP_ID=1000

ARG PHP_BASE_EXTENSIONS="opcache pcntl pdo_mysql pdo_pgsql mongodb redis zip swoole xdebug"
ARG PHP_EXTENSIONS=""
ENV PHP_RUNTIME_EXTENSIONS=""

ARG MYSQL_VERSION="latest"
ARG MARIADB_VERSION="latest"
ARG POSTGRESQL_VERSION="latest"
ARG MONGODB_VERSION="latest"

ENV COMPOSER_HOME="/composer"
ENV COMPOSER_CACHE_DIR="/composer/cache"

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
# Fixes
#--------------------------------------------------------------------------
#

# Copy scripts for fixes that we will use along the image creation.
COPY ./fixes /var/fixes

#
#--------------------------------------------------------------------------
# Package Manager - Switch to reachable repository
#--------------------------------------------------------------------------
#

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
    pnpm -v && \
    # Clean installation leftovers
    apt-get -y autoremove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

#
#--------------------------------------------------------------------------
# Runtime Fixes
#--------------------------------------------------------------------------
#

RUN \
    echo "Ensuring all runtimes have access to low-end port numbers" > /dev/stdout && \
    # Ensure all runtimes have access to privileged ports belo 1024 (like 22, 80 or 443)
    setcap "cap_net_bind_service=+ep" /usr/bin/node && \
    setcap "cap_net_bind_service=+ep" /usr/sbin/sshd && \
    setcap "cap_net_bind_service=+ep" /usr/local/bin/rr && \
    setcap "cap_net_bind_service=+ep" /usr/local/bin/bun && \
    setcap "cap_net_bind_service=+ep" /usr/local/bin/php && \
    setcap "cap_net_bind_service=+ep" /usr/local/bin/deno && \
    setcap "cap_net_bind_service=+ep" /usr/local/bin/composer && \
    setcap "cap_net_bind_service=+ep" /usr/local/bin/frankenphp

#
#--------------------------------------------------------------------------
# User - Preparation
#--------------------------------------------------------------------------
#

RUN \
    echo "Creating symlinks for the '/app' directory" > /dev/stdout && \
    # Symlink the working directory to others default places
    mkdir /app && \
    mkdir -p /var/www && \
    mkdir -p /opt && \
    mkdir -p /home/${USER} && \
    ln -s /app /var/www/html && \
    ln -s /app /opt/project && \
    ln -s /app /home/${USER}/project && \
    # Ensure these path have the correct permissions for the dev user.
    chown $USER_ID:$GROUP_ID /app && \
    chown $USER_ID:$GROUP_ID /var/www/html && \
    chown $USER_ID:$GROUP_ID /opt/project && \
    chown $USER_ID:$GROUP_ID /home/${USER}/project

RUN \
    echo "Ensuring SSH directory can be accessed by ${USER}" > /dev/stdout && \
    # Ensure SSH directories are permissive
    mkdir -p /ssh/sshd_config /ssh/sshd_keys && \
    # Copy the SSH keys generated by OpenSSH Server
    cp /etc/ssh/ssh_host_{rsa,ecdsa,ed25519}_key /ssh/sshd_keys/ && \
    chown -R ${USER_ID}:${GROUP_ID} /ssh

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

RUN \
    echo "Ensure Composer directory is '$COMPOSER_HOME' and the cache is '$COMPOSER_CACHE_DIR'" > /dev/stdout && \
    mkdir ${COMPOSER_HOME} ${COMPOSER_CACHE_DIR} && \
    chown ${USER_ID}:${GROUP_ID} -R /composer

#
#--------------------------------------------------------------------------
# Install S6 Overlay
#--------------------------------------------------------------------------
#
# @see https://github.com/just-containers/s6-overlay
#

RUN /var/fixes/install_s6_overlay.sh

# Copy the S6 Configuration files to the container.
COPY etc /etc

# Set the entrypoint to S6 OVerlay custom INIT.
ENTRYPOINT ["/init"]

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

RUN /var/fixes/set_user.sh

WORKDIR /app
