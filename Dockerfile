FROM dunglas/frankenphp:latest AS frankenphp
FROM ghcr.io/roadrunner-server/roadrunner:latest AS roadrunner
FROM denoland/deno:latest AS deno
FROM oven/bun:latest AS bun
FROM composer:latest AS composer

FROM ubuntu:latest

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

ARG USER_PWD="dev"
ARG S6_OVERLAY_VERSION="3.2.0.2"
ARG S6_OVERLAY_ARCH="x86_64"
ARG PHP_VERSION="latest"
ARG NODE_VERSION="latest"
ARG PGSQL_VERSION="latest"
ARG MYSQL_CLIENT="default-mysql-client"

ENV COMPOSER_HOME="/composer"
ENV COMPOSER_CACHE_DIR="/composer/cache"

ENV PHP_EXTENSIONS=""
ENV USER="dev"
ENV USER_ID=1000
ENV GROUP_ID=1000

SHELL ["/bin/bash", "-c"]

#
#--------------------------------------------------------------------------
# Common fixes
#--------------------------------------------------------------------------
#

# Fix APT
RUN echo "Acquire::http::Pipeline-Depth 0;" > /etc/apt/apt.conf.d/99custom && \
    echo "Acquire::http::No-Cache true;" >> /etc/apt/apt.conf.d/99custom && \
    echo "Acquire::BrokenProxy    true;" >> /etc/apt/apt.conf.d/99custom

# Copy some scripts for fixes and allow these to be executable
COPY ./fixes /var/fixes

#
#--------------------------------------------------------------------------
# Install from layers
#--------------------------------------------------------------------------
#
# We're going to install all these utilities to the "/usr/local/bin" path
# because this is the place for manually installed command utilities.
#

COPY --from=frankenphp  /usr/local/bin/frankenphp   /usr/local/bin/frankenphp
COPY --from=roadrunner  /usr/bin/rr                 /usr/local/bin/rr
COPY --from=deno        /usr/bin/deno               /usr/local/bin/deno
COPY --from=bun         /usr/local/bin/bun          /usr/local/bin/bun
COPY --from=composer    /usr/bin/composer           /usr/local/bin/composer


#
#--------------------------------------------------------------------------
# Package Manager - Install Base Software
#--------------------------------------------------------------------------
#

RUN \
    echo "Setting base utilities for the container" > /dev/stdout && \
    apt-get update && apt-get upgrade -y && \
    apt-get install -y \
      curl \
      ca-certificates \
      dnsutils \
      fswatch \
      ffmpeg \
      git \
      gnupg \
      gosu \
      jq \
      libcap2-bin \
      libpng-dev \
      librsvg2-bin \
      nano \
      openssh-server \
      python3 \
      supervisor \
      sqlite3 \
      unzip \
      zip && \
    # Clean installation leftovers
    apt-get -y autoremove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

#
#--------------------------------------------------------------------------
# Package Manager - Prepare Repositories
#--------------------------------------------------------------------------
#

RUN echo 'Adding repositories' > /dev/stdout && \
    mkdir -p /etc/apt/keyrings && \
    /var/fixes/add_repositories.sh

#
#--------------------------------------------------------------------------
# Package Manager - Install Runtimes
#--------------------------------------------------------------------------
#

RUN \
    apt-get update && \
    # Install PHP
    echo 'Installing PHP' > /dev/stdout && \
    /var/fixes/install_php.sh && \
    # Install Node
    echo 'Installing Node' > /dev/stdout && \
    apt-get install -y nodejs && \
    # Enable Corepack
    echo 'Enabling Node Corepack (which also enables PNPM and Yarn)' > /dev/stdout && \
    corepack enable && \
    # Install NPM
    echo 'Updating NPM by installing it again (by itself)' > /dev/stdout && \
    npm install -g npm && \
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
    setcap "cap_net_bind_service=+ep" /usr/local/bin/deno && \
    setcap "cap_net_bind_service=+ep" /usr/local/bin/composer && \
    setcap "cap_net_bind_service=+ep" /usr/local/bin/frankenphp

#
#--------------------------------------------------------------------------
# Package Manager - Install Utilities
#--------------------------------------------------------------------------
#

RUN \
    apt-get update && \
    # Install MySQL Client
    echo "Installing MySQL Client (as '$MYSQL_CLIENT')" > /dev/stdout && \
    apt-get install -y $MYSQL_CLIENT && \
    # Install PostgreSQL Client
    echo 'Installing PostgreSQL Client' > /dev/stdout && \
    /var/fixes/install_pgsql_client.sh && \
    # Clean installation leftovers
    apt-get -y autoremove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

#
#--------------------------------------------------------------------------
# User - Preparation
#--------------------------------------------------------------------------
#

RUN \
    echo "Creating symlinks for the '/app' directory" > /dev/stdout && \
    # Symlink the working directory to others default places
    mkdir /app && \
    mkdir -p /var/www/html && \
    mkdir -p /opt/project && \
    mkdir -p /home/${USER}/project && \
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
# to the build time, in case extension installation return errors.
#

RUN \
    echo "Installing additional PHP Extensions" && > /dev/stdout \
    apt-get update && \
    /var/fixes/install_php_extensions.sh && \
    apt-get -y autoremove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

#
#--------------------------------------------------------------------------
# Install S6 Overlay
#--------------------------------------------------------------------------
#
# @see https://github.com/just-containers/s6-overlay
#

ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz /tmp

# Decompress and remove the source files.
RUN \
    echo "Installing S6 Overlay v${S6_OVERLAY_VERSION} for '$S6_OVERLAY_ARCH'" > /dev/stdout && \
    tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz && \
    tar -C / -Jxpf /tmp/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz && \
    rm /tmp/s6-overlay-noarch.tar.xz /tmp/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz

# Copy the S6 Configuration files to the container.
COPY etc /etc

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

RUN /var/fixes/adjust_user.sh

WORKDIR /app

USER ${USER}

CMD ["/bin/bash"]

ENTRYPOINT ["/init"]
