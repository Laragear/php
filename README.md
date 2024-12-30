# PHP Container for development

Swiss-knife Docker/Podman/Rancher container for PHP development, from PHP 5.6 to the latest versions.

```shell
docker run laragear/php -v ~/projects/my-app:/app php -v
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

```shell
docker build laragear/php
```

Alternatively, you can also bring this image through the GitHub Container Repository by prefixing `ghcr.io/` to the image.

```shell
docker build ghcr.io/laragear/php
```

This PHP image for development is re-built every Tuesday and Thursday at 07:00 UTC. This means you will always have an updated development environment with all tools upgraded to their latest versions.

## Software included

This image includes everything to run in your development environment and then some.

- [Composer](https://getcomposer.org/)
- [XDebug](https://xdebug.org/)
- [Swoole](https://swoole.com/)
- [PHP Extension installer](https://github.com/mlocati/docker-php-extension-installer)
- [FrankenPHP](https://frankenphp.dev/)¹
- [RoadRunner](https://roadrunner.dev/)²
- [Node](https://nodejs.org/)⁴, [Bun](https://bun.sh/) and [Deno](https://deno.com/)
- [NPM](https://www.npmjs.com/)³, [Yarn](https://yarnpkg.com/)³ and [PNPM](https://pnpm.io/)³
- Database Clients for [MySQL](https://dev.mysql.com/downloads/shell/), [PostgreSQL](https://www.postgresql.org/docs/current/app-psql.html), [MariaDB](https://mariadb.com/docs/server/connect/clients/mariadb-client/), [SQLite](https://sqlite.org/cli.html) and [MongoDB](https://www.mongodb.com/docs/mongocli/)⁴.
- SSH Server (rootless)

> [!NOTE]
>
> ¹: FrankenPHP requires [PHP 8.2 or latter](https://github.com/dunglas/frankenphp/issues/637#issuecomment-1986480954).
>
> ²: RoadRunner requires [PHP 7.4 or latter](https://github.com/roadrunner-php/cli/blob/dddbf4c7c95c27cee8f115bbd6d4361a4e88a9e7/composer.json#L27).
>
> ³: Installed as part of [Corepack](https://nodejs.org/api/corepack.html). Not available on [EOL Debian images](https://wiki.debian.org/DebianReleases#Production_Releases) (like those using PHP 7.0 and PHP 5.6).
> 
> ⁴: Not available on [EOL Debian images](https://wiki.debian.org/DebianReleases#Production_Releases) (like those using PHP 7.0 and PHP 5.6).
 
## Tags

Laragear PHP is built for PHP 5.6 onwards. Debian versions depend on the PHP version you're using, as this image is based on the [official PHP Image from Docker](https://github.com/docker-library/php). These images will always use the latest Debian version available.

| Tags                 | Status    | PHP Version | Debian Version                                            |
|----------------------|-----------|-------------|-----------------------------------------------------------|
| `8.4` `latest` `1.x` | Supported | `8.4`       | [`11.0` Bookworm](https://wiki.debian.org/DebianBookworm) |
| `8.3`                | Supported | `8.3`       | [`11.0` Bookworm](https://wiki.debian.org/DebianBookworm) |
| `8.2`                | Security  | `8.2`       | [`11.0` Bookworm](https://wiki.debian.org/DebianBookworm) |
| `8.1`                | Security  | `8.1`       | [`11.0` Bookworm](https://wiki.debian.org/DebianBookworm) |
| `8.0`                | EOL       | `8.0`       | [`11.0` Bullseye](https://wiki.debian.org/DebianBullseye) |
| `7.4`                | EOL       | `7.4`       | [`11.0` Bullseye](https://wiki.debian.org/DebianBullseye) |
| `7.3`                | EOL       | `7.3`       | [`11.0` Bullseye](https://wiki.debian.org/DebianBullseye) |
| `7.2`                | EOL       | `7.2`       | [`10.0` Buster](https://wiki.debian.org/DebianBuster)     |
| `7.1`                | EOL       | `7.1`       | [`10.0` Buster](https://wiki.debian.org/DebianBuster)     |
| `7.0`                | EOL       | `7.0`       | [` 9.0` Stretch](https://wiki.debian.org/DebianStretch)   |
| `5.6`                | EOL       | `5.6`       | [` 9.0` Stretch](https://wiki.debian.org/DebianStretch)   |

> [!WARNING]
> 
> [Unsupported PHP Versions](https://www.php.net/supported-versions.php) may not work properly. Be sure to always stay up to date.

### DevContainer

You may use the [`devcontainer.json`](devcontainer.json) file as DevContainer development environment, or copy-and-paste it to your liking in your own project.

If you're using a DevContainer through a Docker Compose file, set the image to be used as `laragear/php`, with a tagged version if possible.

```yaml
services:
    
  app-dev:
    image: laragear/php:8.3
    extra_hosts:
      - 'host.docker.internal:host-gateway'
    # ...
```

## PHP Extensions

This image includes the following PHP extensions installed:

|            |           |         |          |
|------------|-----------|---------|----------|
| PostgreSQL | SQLite    | MongoDB | MySQL    |
| bcmath     | curl      | gd      | igbinary |
| imagick    | imap      | intl    | ldap     |
| mbstring   | memcached | msgpack | pcov     |
| readline   | redis     | soap    | XML      |
| Xdebug     | zip       |         |          | 

### Adding extensions

You can add extensions to your image runtime by using the `PHP_RUNTIME_EXTENSIONS` environment variable, separating each extension name by comma. These will be passed to the [`install-php-extensions`](https://github.com/mlocati/docker-php-extension-installer) utility.

```shell
docker run laragear/php \
  -e PHP_RUNTIME_EXTENSIONS="first-extension second-extensions:1.4"
```

Because these extensions are installed at runtime, the container may take a while to fully start until the extensions are compiled and installed. This only happens if an extension is not installed.

> [!WARNING]
> 
> When adding extensions to old PHP versions, you may need to set a fixed version. Most of the "latest" versions of extensions deprecate unsupported PHP versions.
> 
> For example, installing `sqlsrv` on `php:7.4` won't work, as it will install the latest `v5.12.0`. Instead, you will need to set the proper version that supports PHP 7.4, as `sqlsrv:5.10.1`. You can see supporting versions of each extension at [PECL](https://pecl.php.net/).

## Composer Cache

The composer cache is located at `/composer/cache`. You can mount your host Composer Cache, which should make the dependencies installation and updating _faster_ if you're running a lot of Composer projects with a common cache.

```shell
docker run laragear/php \
  -v ~/.composer/cache:/composer/cache \
  composer install
```

## Custom User & Group ID

The default user for the container is `developer`, which is mapped as `1000:1000`.

You may change the username, ID, and Group ID at build time using the `USER`, `USER_ID` and `GROUP_ID` arguments, respectively.

```shell
docker run laragear/php \
  -e USER=vscode \
  -e USER_ID=1001 \
  -e GROUP_ID=1001
```

> [!WARNING]
> 
> You should ensure you set the User ID and Group ID to your current one. If these are not equal, the container won't work, or you may have permissions problems between the container and your project.

## SSH Server

This container includes an SSH Server running as the default user (non-privileged) and listening to the `22` port, which is **not** exposed by default.

```shell
docker run laragear/php -p 2222:22
```

### Username and password

The default username for the container is `developer`, and the password is also `developer`. You can change the user and password via environment variables. 

```shell
docker run laragear/php \
  -e USER=vscode \
  -e USER_PWD=my-secure-password
```

> [!TIP]
> 
> SSH Login for the root user is disabled. If you require to do changes as root, enter the container directly.

### Reusing SSH Container Keys

When the container starts, a set of keys will be created in `/ssh/ssh_keys` if these do not exist. To avoid SSH keys changing every time you re-create the container, you can mount an empty directory there to keep these keys consistent between recreations. For example, you can mount it from `~/.ssh/laragear-ssh`.

```shell
docker run laragear/php \
  -v ~/.ssh/laragear-ssh:/ssh/ssh_keys 
  php -v
```

> [!TIP]
> 
> If these keys do not exist, they're copied from the container automatically for your convenience. 

Alternatively, while not entirely recommended, you may also set your SSH configuration in `.ssh/config` to disable strict check of the host keys in the computer you're connecting from.

```shell
Host my-project.laragear
  ForwardAgent yes
  LogLevel error
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  HostKeyAlgorithms rsa-sha2-256,rsa-sha2-512,ssh-rsa
  Hostname my-computer.lan
  Port 2222
  User dev
```

## Workdir and mounts

The default working directory is `/app`. When mounting your project, set this path as the target.

```shell
docker run laragear/php \
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
