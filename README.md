# PHP Container for development

Swiss-knife Docker/Podman/Rancher container for PHP development, from PHP 7.0 to latest PHP.

```shell
docker run ghcr.io/laragear/php -v ~/projects/my-app:/app:z php -v
```

> [!NOTE]
> 
> This a development image, not tailored for production. If you need a production image, I recommend [Server Side Up PHP Container](https://serversideup.net/open-source/docker-php).

## Become a sponsor

[![](.github/assets/support.png)](https://github.com/sponsors/DarkGhostHunter)

Your support allows me to keep this package free, up-to-date and maintainable.

## Requirements

* Docker, Podman, Rancher, or any other OCI runtime.

## Usage

In your IDE of choice, like PHPStorm or VSCode, point this Docker image as a remote PHP interpreter:

    ghcr.io/laragear/php

## Software included

This image includes everything to run in your development environment and then some.

- [XDebug](https://xdebug.org/)
- [Composer](https://getcomposer.org/)
- [FrankenPHP](https://frankenphp.dev/)¹
- [RoadRunner](https://roadrunner.dev/)²
- [Swoole](https://swoole.com/) PHP Extension³
- [Node](https://nodejs.org/)⁴, [Bun](https://bun.sh/) and [Deno](https://deno.com/)
- [NPM](https://www.npmjs.com/), [Yarn](https://yarnpkg.com/)⁴ and [PNPM](https://pnpm.io/)⁴
- [MySQL](https://dev.mysql.com/downloads/shell/), [PostgreSQL](https://www.postgresql.org/docs/current/app-psql.html) CLI clients
- SSH Server (rootless)

> [!NOTE]
>
> ¹: FrankenPHP is only compatible with PHP 8.2 onwards.
> 
> ²: RoadRunner is only compatible with PHP 8.0 onwards.
> 
> ³: Installable as long it's released for the given PHP Version.
> 
> ⁴: With Corepack enabled

### PHP Version

By default, this container installs the latest stable PHP Version from [Ondřej Surý](https://launchpad.net/~ondrej/+archive/ubuntu/php/). You can change which version of PHP install during build time using the `PHP_VERSION` argument.

```shell
docker build ghcr.io/laragear/php \
  --build-arg PHP_VERSION=7.4
```

> [!NOTE]
> 
> Only set the MAJOR and MINOR versions, like "8.4". Trying to set the patch version won't work. This always install the latest patch version, so there is no need to set it.

#### Extensions

This image includes the following extensions installed:

|            |           |         |          |
|------------|-----------|---------|----------|
| PostgreSQL | SQLite    | MongoDB | MySQL    |
| bcmath     | curl      | gd      | igbinary |
| imagick    | imap      | intl    | ldap     |
| mbstring   | memcached | msgpack | pcov     |
| readline   | redis     | soap    | XML      |
| zip        |           |         |          | 

You can add extensions to your image at build time using the `PHP_EXTENSIONS` environment variable, separating each extension name by comma. These will be passed to `apt-get` to be installed from Ondřej Surý repository.

```shell
docker build ghcr.io/laragear/php \
  --build-arg PHP_VERSION=7.4 \
  --build-arg PHP_EXTENSIONS=enchant,phpdbg
``` 

### Composer Cache

The composer cache is configured to be located at `/composer/cache`. You can mount your host Composer Cache, which should make the dependencies installation and updating _faster_ if you're running a lot of Composer projects with a common cache.

```shell
docker run ghcr.io/laragear/php \
  -v ~/.composer/cache:/composer/cache 
  composer install
```

### Custom User & Group ID

The default user for the container is `dev`, which is mapped as `1000:1000`.

You may change the username, ID, and Group ID at build time using the `USER`, `USER_ID` and `GROUP_ID` arguments, respectively.

```shell
docker build ghcr.io/laragear/php \
  --build-arg USER=vscode \
  --build-arg USER_ID=1001 \
  --build-arg GROUP_ID=1001
```

> [!WARNING]
> 
> You should ensure you set the User ID and Group ID to your current one. If these are not equal, the container won't work, or you may have permissions problems between the container and your project.

### SSH Server

This container includes an SSH Server running as the default user (non-privileged) and listening to the `22` port, which is not exposed by default.

```shell
docker run ghcr.io/laragear/php -p 2222:22
```

#### Username and password

The default username for the container is `dev`, and the password is also `dev`. You may change these at build time using the `USER` and `USER_PWD` arguments, respectively

```shell
docker build ghcr.io/laragear/php \
  --build-arg USER=vscode \
  --build-arg USER_PWD=my-secure-password
```

> [!TIP]
> 
> SSH Login for the root user is disabled. If you require to do changes as root, enter the container directly.

#### Reusing SSH Container Keys

When the container starts, a set of keys will be created in `/ssh/ssh_keys` if these do not exist. To avoid SSH keys changing every time you re-create the container, you can mount an empty directory there to keep these keys consistent between recreations. For example, you can mount it from `~/.ssh/laragear-ssh`.

```shell
docker run ghcr.io/laragear/php -v ~/.ssh/laragear-ssh:/ssh/ssh_keys php -v
```

> [!TIP]
> 
> If these keys do not exist, they're copied from the container automatically for your convenience. 

Alternatively, while not entirely recommended, you may also set your SSH configuration in `.ssh/config` to disable strict check of the host keys in the computer you're connecting from.

```shell
Host my-project.devpod
  ForwardAgent yes
  LogLevel error
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  HostKeyAlgorithms rsa-sha2-256,rsa-sha2-512,ssh-rsa
  Hostname my-computer.lan
  Port 2222
  User dev
```

### Workdir and mounts

The default working directory is `/app`. When mounting your project, set this path as the target.

```shell
docker run ghcr.io/laragear/php \
  -v ~/projects/my-app:/app \
  composer install
```

> [!TIP]
> 
> Some DevContainer or IDE will auto-mount the project to an alternative path. This container symlinks `/app` to these targets: `/var/www/html`, `/opt/project`, and `~/project`. 

## Security

If you discover any security related issues, please email darkghosthunter@gmail.com instead of using the issue tracker.

# License

This specific package version is licensed under the terms of the [MIT License](LICENSE.md), at time of publishing.

[Laravel](https://laravel.com) is a Trademark of [Taylor Otwell](https://github.com/TaylorOtwell/). Copyright © 2011-2024 Laravel LLC.
