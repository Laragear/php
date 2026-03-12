ARG PHP_VERSION="latest"
ARG COMPOSER_VERSION="latest"
ARG FRANKENPHP_VERSION="latest"
ARG RR_VERSION="latest"
ARG NODE_VERSION="latest"
ARG DENO_VERSION="latest"
ARG BUN_VERSION="latest"
ARG S6_VERSION="latest"

### Only add images here that can be set with versions via Build Arguments.
### The purpose of this block is to cache these images when building the
### main image at the very beginning of that GitHub Actions Workflow.

# Common images start
FROM composer:${COMPOSER_VERSION} AS composer-image
FROM node:${NODE_VERSION} AS node-image
FROM dunglas/frankenphp:${FRANKENPHP_VERSION} AS frankenphp-image
FROM ghcr.io/roadrunner-server/roadrunner:${RR_VERSION} AS roadrunner-image
FROM denoland/deno:${DENO_VERSION} AS deno-image
FROM oven/bun:${BUN_VERSION} AS bun-image
# Common images end

FROM php:${PHP_VERSION}

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

ENV USER_PWD="developer"
ENV USER="developer"
ENV USER_ID=1000
ENV GROUP_ID=1000
ENV HOME="/home/$USER"
ENV PROJECT_PATH="/app"

ARG PHP_BASE_EXTENSIONS="opcache pdo_mysql pdo_pgsql mongodb redis intl bcmath zip xdebug"
ARG PHP_EXTENSIONS=""
ENV PHP_RUNTIME_EXTENSIONS=""

ARG MYSQL_VERSION="latest"
ARG MARIADB_VERSION="latest"
ARG POSTGRESQL_VERSION="latest"
ARG MONGODB_VERSION="latest"

ENV COMPOSER_HOME="/composer"
ENV COMPOSER_CACHE_DIR="$COMPOSER_HOME/cache"
ENV COMPOSER_BIN_DIR="$COMPOSER_HOME/bin"

ENV PATH=$PATH:$COMPOSER_BIN_DIR

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
        echo "Acquire::atp::No-Cache true;" >> /etc/apt/apt.conf.d/99custom && \
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
    # Add a retry logic on install (up to 3 times) \
    for attempt in 1 2 3; do \
        apt-get install -y --no-install-recommends --fix-missing \
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
            zip && break || \
        if [ "$attempt" -lt 3 ]; then \
            echo "Attempt $attempt failed! Retrying..."; \
            sleep 2; \
        else \
            echo "Final attempt failed. Exiting."; \
            exit 1; \
        fi; \
    done && \
    # Check if YQ is available. If not, don't install it. \
    if apt-get install --dry-run yq &> /dev/null; then \
      apt-get install -y --no-install-recommends yq; \
    fi && \
    # Check if FSWATCH is available. If not, don't install it. \
    if apt-get install --dry-run fswatch &> /dev/null; then \
      apt-get install -y --no-install-recommends fswatch; \
    fi && \
    # Clean installation leftovers \
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

RUN set -e; \
    for EXT in $PHP_BASE_EXTENSIONS; do \
        echo "Attempting to install $EXT..."; \
        # Try the base extension first \
        if install-php-extensions "$EXT"; then \
            echo "✅ $EXT installed successfully."; \
        else \
            # Check if the failing extension is 'swoole' \
            if [ "$EXT" = "swoole" ]; then \
                echo "⚠️ Standard install failed for $EXT. Trying pre-release suffixes..."; \
                \
                FOUND=false; \
                for SUFFIX in "-rc" "-beta" "-alpha" "-devel" "-snapshot"; do \
                    echo "Testing $EXT$SUFFIX..."; \
                    if install-php-extensions "$EXT$SUFFIX"; then \
                        echo "✅ Successfully installed $EXT as $EXT$SUFFIX"; \
                        FOUND=true; \
                        break; \
                    fi; \
                done; \
                \
                if [ "$FOUND" = false ]; then \
                    echo "❌ Could not install $EXT with any known suffix."; \
                    exit 1; \
                fi; \
            else \
                # Fail immediately for any other extension \
                echo "❌ Failed to install $EXT. Suffixes are only permitted for 'swoole'."; \
                exit 1; \
            fi; \
        fi; \
    done

#
#--------------------------------------------------------------------------
# Package Manager - Enable PHP base Extensions
#--------------------------------------------------------------------------
#

RUN echo "Enabling PCNTL"; \
    docker-php-ext-install pcntl

#
#--------------------------------------------------------------------------
# Package Manager - Complete Node Runtime install
#--------------------------------------------------------------------------
#

RUN \
    apt-get update && \
    # Install Node \
    echo 'Installing Node' > /dev/stdout && \
    apt-get install -y --no-install-recommends nodejs && \
    # Enable Corepack  \
    if [ -f '/usr/bin/corepack' ]; then \
        # Update Corepack \
        echo 'Update Corepack' > /dev/stdout && \
        npm install --global corepack@latest && \
        # Enable NPM \
        echo 'Enabling Corepack' > /dev/stdout && \
        corepack enable && \
        # Enable NPM \
        echo 'Installing NPM via Corepack' > /dev/stdout && \
        corepack install --global npm && \
        # Enable Yarn \
        echo 'Installing Yarn via Corepack' > /dev/stdout && \
        corepack install --global yarn && \
        # Yarn smoke test \
        yarn -v && \
        # Enable PNPM \
        echo 'Installing PNPM via Corepack' > /dev/stdout && \
        corepack install --global pnpm && \
        # PNPM smoke test \
        pnpm -v; \
    else \
      echo 'This version of Debian does not support Node Corepack' > /dev/stdout; \
    fi && \
    # Clean installation leftovers \
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
    # Ensure SSH directories are permissive \
    mkdir -p /ssh/sshd_config /ssh/sshd_keys && \
    # Copy the SSH keys generated by OpenSSH Server \
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
    if php -r "exit(version_compare(PHP_VERSION, '7.2.5', '<') ? 0 : 1);" ; then \
      echo 'Downgrading Composer to version 2.2...'; \
      curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer --2.2; \
    fi

# Enable plugins. It's a Docker Container, so it will only affect the container.
RUN \
   echo 'Enabling plugins in Composer...'; \
   sudo -u $USER /usr/local/bin/composer global config --no-plugins allow-plugins true

# Let's also add some common composer utilities globally.
#
# - `laravel/installer`:            It install Laravel for you.
# - `laravel-zero/installer`:       It install Laravel Zero, a great CLI framework.
# - `vildanbina/composer-upgrader`: Upgrade all your dependencies to their latest versions effortlessly.
# - `nunomaduro/phpinsights`:       Instant analysis of your code quality, complexity, and architecture.
#
RUN \
    PACKAGES="laravel/installer vildanbina/composer-upgrader nunomaduro/phpinsights" && \
    # Append :@dev to each package name \
    UPDATED_PACKAGES="" && \
    for PKG in $PACKAGES; do UPDATED_PACKAGES="$UPDATED_PACKAGES ${PKG}:@dev"; done && \
    PACKAGES=$(echo $UPDATED_PACKAGES | xargs) && \
    \
    echo "Adding some useful Composer packages globally: $PACKAGES" > /dev/stdout && \
    sudo -u $USER /usr/local/bin/composer global require --no-cache --prefer-stable $PACKAGES && \
    \
    # Clear composer cache and keep the image size lean \
    sudo -u $USER /usr/local/bin/composer clear-cache

# Finally, add Mago (Larastan + Pint + Linter) that runs using Rust instead of PHP, which is 50x faster.
#
# For more info: https://mago.carthage.software/tools/formatter/configuration-reference
#
RUN \
    if php -r "exit(version_compare(PHP_VERSION, '8.1.0', '>=') ? 0 : 1);"; then \
      curl --proto '=https' --tlsv1.2 -sSf https://carthage.software/mago.sh | bash; \
    fi

#
#--------------------------------------------------------------------------
# Runtime Fixes
#--------------------------------------------------------------------------
#

# Ensure all runtimes have access to privileged ports belo 1024 (like 22, 80 or 443)
RUN \
    echo "Ensuring all runtimes have access to low-end port numbers" > /dev/stdout && \
    # Old Node sometimes installs itself has "nodejs", so use that if "node" doesn't exists. \
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
    setcap "cap_net_bind_service=+ep" /usr/local/bin/mago && \
    setcap "cap_net_bind_service=+ep" /usr/local/bin/composer && \
    setcap "cap_net_bind_service=+ep" /usr/local/bin/frankenphp && \
    setcap "cap_net_bind_service=+ep" /usr/local/bin/chromedriver

#
#--------------------------------------------------------------------------
# Common fixes
#--------------------------------------------------------------------------
#

COPY ./fixes/set_timezone.sh /var/fixes/set_timezone.sh

RUN /var/fixes/set_timezone.sh

#
#--------------------------------------------------------------------------
# Make the container ready to use
#--------------------------------------------------------------------------
#

WORKDIR /app

CMD ["/bin/bash"]
