# Docker Spotweb Image
An image running [ubuntu/20.04](https://hub.docker.com/_/ubuntu/) Linux and [Spotweb](https://github.com/spotweb/spotweb).

## Requirements
You need a seperate MySQL/MariaDB/PostGreSQL server. This can of course be a (linked) docker container [MySQL](https://hub.docker.com/_/mysql) / [MariaDB](https://hub.docker.com/_/mariadb)/[PostGreSQL](https://hub.docker.com/_/postgres), but also a dedicated database server [MySQL](https://www.mysql.com/) / [MariaDB](https://mariadb.org/)/[PostGreSQL](https://www.postgresql.org/).

## MYSQL 8
At present, if you use spotweb with a MYSQL 8 database, it will fail to first authenticate (Error 1044), then create the spotweb user (Error 1410).  To get around these issues keep everything filled in in the spotweb install.php page:
### Allow Access To MYSQL 8 from Docker
Log into the mysql host as root:
`mysql -uroot -p`
Create another root user, who's domain is the docker network (replace `<root password>` with the password you gave as your root password on `install.php`):
```
CREATE USER 'root'@'172.19.0.%' IDENTIFIED BY '<root password>';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'172.19.0.%';
GRANT GRANT OPTION ON *.* TO 'root'@'172.19.0.%';
```
### Creating The Initial User
If you try and continue (click next) in spotweb, it will now fail with a different error about not being to create a user with a grant option (Error 1410).  To get around this, you need to create the user first, again loginto mysql (hopefully you haven't logged out yet) and, type (replacing `<spotweb username>` with the username you gave on `install.php` and replacing `<spotweb user password>` with the spotweb user password you supplied on `install.php`):
```
CREATE USER '<spotweb username>' IDENTIFIED BY '<spotweb user password>';
FLUSH PRIVILEGES;
```
You should now be able to click next and continue.

## Usage
### Step 1) Initial Installation
First create a database on your database server, and make sure the container has access to the database, then run a temporary container.
```
    docker run -it ajw107/spotweb -p <external port>:80
```
**NOTE**: There is no database configuration here, this will enable the install process.
Then run the Spotweb installer using the web interface `http://<yourhost>:<external port>/install.php`.
This will create the necessary database tables and users. Ignore the warning when it tries to save the configuration.
When you are done, exit the container (CTRL/CMD-c) and configure the permanent running container, as follows.

### Step 2) Permanent Installation
**NOTE**: See below for docker-compose example (please only use docker-compose from this step, 2, onwards.  Do not do Step 1 using docker compose)
To create the permanent
```
    docker run --restart=always -d \
        --hostname=spotweb \
        --name=spotweb \
        -v <hostdir_where_config_will_persistently_be_stored>:/config \
        -e 'TZ=Europe/Amsterdam' \
        -e 'SPOTWEB_DB_TYPE=pdo_mysql' \
        -e 'SPOTWEB_DB_HOST=<database_server_hostname>' \
        -e 'SPOTWEB_DB_PORT=<database_port>' \
        -e 'SPOTWEB_DB_NAME=spotweb' \
        -e 'SPOTWEB_DB_USER=spotweb' \
        -e 'SPOTWEB_DB_PASS=An_Incredibly.Complex^Password-For!Spotweb' \
        -e 'SPOTWEB_CRON_RETRIEVE=*/15 * * * *' \
        -e 'SPOTWEB_CRON_CACHE_CHECK=20 * * * *' \
        --build-arg 'SPOTWEB_BRANCH=master' \
        --build-arg 'PHP_VER=7.4' \
        -p 8080:80 \
        ajw107/spotweb
```
#### Detaching
Please note this command uses the -d argument to detach from the container once it has started.  This is so you don't have the log file open all the time, and it can run in the background (so you can't use CTRL+C to exit).  To start and stop the container, you can now just do (replace spotweb with the name you gave the container in the command above):
`docker start spotweb`
and
`docker stop spotweb`

#### REQUIRED Args
To define an already existing database (such as the one you just created in the previous step) you MUST supply at least:
- `SPOTWEB_DB_TYPE`
- `SPOTWEB_DB_HOST`
- `SPOTWEB_DB_NAME`
- `SPOTWEB_DB_USER`
- `SPOTWEB_DB_PASS`

or the database configuration will not be created and spotweb will go into setup mode.
**NOTE**: `SPOTWEB_DB_TYPE` is the name of the driver to connect to the database engine with.  This is normally `pdo_mysql` for MYSQL databases and it's off-shoots, `pdo_pgsql` for PostGreSQL databases (the only two database engines recommended by spotweb).  `pdo_sqlite3` can be used for sqlite3 databases, but this is experimental and not recommended by spotweb.
**TIP**: If you've forgotten the details you just entered (it happens to us all), especially passwords just run (for database settings):
`sudo find /var/lib/docker/ -iname "dbsettings.inc.php" -exec cat "{}" \;`

#### OPTIONAL Args
- `SPOTWEB_DB_PORT`: If omitted it will use the standard port for MySQL / PostgreSQL (3306).
- `SPOTWEB_CRON_RETRIEVE`: Used to automatically retreive new sports (see below)
- `SPOTWEB_CRON_CACHE_CHECK`: Used to automatically check the validty of the articles cache (see below)
- `SPOTWEB_BRANCH`: Used when building the container to specify the git branch to use (not needed in normal use, defaults to master)
- `PHP_VER`: Used when building the container to specify the version fo PHP to use (not needed in normal use, defaults to 7.4).  **NOTE**: If using MYSQL 8 as a backend you will need to make sure the version of PHP you use supports `caching_sha2_password` authentication.  Google: `"pdo_mysql" "caching_sha2_password"` and try not to cry).

#### Volumes
- `/config` volume is optional. Only necessary when you have configuration settings you wish to keep between different docker runs.

#### Ports
Use the -p option to specify an external port `-p <external port>:80` eg:
`-p 8080:80`
this is useful for port forwarding, etc.  Spotweb will then be available on `http://<hostname or ip of docker host>:<external port>` e.g.:
`http://12.34.56.78:8080`
If you do not specify an external port, or you specify `-p 80:80` then don't include :<external port> e.g.:
`http://12.34.56.78`
**TIP**: If you need to access spotweb from inside another docker container on the same docker network, you can just specify the spotweb container name or hostname if you specified the `--hostname=` option `http://<name of spotweb container>` and the docker dns resolver should do the rest for you.  eg:
`http://spotweb`
If you need to access from within another docker (for instance behind a nginx reverse proxy), don't bother specifiying the -p option at all.

#### Automatic Retrieval Of New Spots
To enable automatic retrieval, you need to setup a [cronjob](https://en.wikipedia.org/wiki/Cron) on either the docker host or within the container.
##### On The Docker Host
To enable automatic retrieval, you need to setup a [cronjob](https://en.wikipedia.org/wiki/Cron) on the docker host.
`*/15 * * * * docker exec spotweb su -l www-data -s /usr/bin/php /var/www/spotweb/retrieve.php >/dev/null 2>&1`
This example will retrieve new spots every 15 minutes.
##### In The Docker Container
To enable automatic retrieval from within the container, use the `SPOTWEB_CRON_RETRIEVE` variable to specify the [cron timing](https://en.wikipedia.org/wiki/Cron) for retrieval. For example as additional parameter to the `docker run` command:
`-e 'SPOTWEB_CRON_RETRIEVE=*/15 * * * *'`
#### Automatic Article Cache Checking
To run a sanity check on the article cache on a regular interval, use the `SPOTWEB_CRON_CACHE_CHECK` variable to speicfy it in [cron format](https://en.wikipedia.org/wiki/Cron). e.g. to run a check every hour at 20 past:
`-e 'SPOTWEB_CRON_CACHE_CHECK=20 * * * *'`

### Step 3) Accessing Spotweb
You should now be able to reach the spotweb interface on:
- **First time users/New install without database**: `http://<hostname or ip of the docker host>:<external port>/install.php`
- **If you specified an already existing database**: `http://<hostname or ip of the docker host>:<external port>`

**NOTE**:
- The hostname or ip address of the docker host means the machine you are running docker on, not the hostname or ip address of the docker container
- If you haven't specified an external ip (or you specified `-p 80:80`), there is no need to include :<external port> (see above)
### Updates
The container will try to auto-update the database when a newer version is released.
**NOTE**:This will NOT update the spotweb installation, the only way of doing that is to download a newer docker image, or use the Dockerfile to build it yourself (just clone the git repo `github.com/ajw107/spotweb` and run `buildNoCache.sh`).

### Alternative Step 2) Using Docker-Compose
To prevent you from typing long command lines, and easily editing the container settings you can use [docker-compose](https://github.com/docker/compose) to vasly simplfy things.  You can even define multiple dockers in one file and have them on the same network so they can easily talk to each other, or have multiple docker compose files to keep some containers seperate from each other.  It even starts and stops the containers in the right order for you.
An example docker-compose.yml file entry would be (... just signifies a gap where configurations for other containers go, **DO NOT** put the dots in):
```
---
version: "3.7"

volumes:
  spotweb-appdata-volume:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /path/to/my/spotweb/data

services:
  spotweb-service:
    image: ajw107/spotweb
    container_name: spotweb-service
    environment:
      - TZ="Europe/London"
      - SPOTWEB_BRANCH=master
      - SPOTWEB_CRON_RETRIEVE=*/15 * * * *
      - SPOTWEB_CRON_CACHE_CHECK=20 */1 * * *
    env_file:
      - spotweb.env
    ports:
      - 2080:80
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - spotweb-appdata-volume:/config
    restart: unless-stopped

networks:
  default:
    name: webserver-apps_network
```
and the contents of spotweb.env would look something like:
```
MYSQL_ROOT_PASSWORD=Very-Complex$Root.Password
SPOTWEB_DB_TYPE=pdo_mysql
SPOTWEB_DB_HOST=123.45.67.8
SPOTWEB_DB_NAME=spotweb
SPOTWEB_DB_USER=spotweb
SPOTWEB_DB_PASS=Even~More-Complex$Spotweb.Password
```
Obviously change the values in both files to your own settings.  The only issue is that docker-compose uses [YAML](https://en.wikipedia.org/wiki/YAML), which is very picky about indentation (which is quite good as it makes things easier to read), but can get very annoying when an error is that a tab has been instead of a space, or there is one space too many/few somewhere.

### Environment variables
| Variable | Function | Default | Example |
| --- | --- | --- | --- |
| `TZ` | The timezone the server is running in. | `Europe/Amsterdam` | `-e 'TZ=Europe/London'` |
| `SPOTWEB_DB_TYPE` | Database type. | - | `-e 'SPOTWEB_DB_TYPE=pdo_mysql'` |
| `SPOTWEB_DB_HOST` | The database hostname / IP. | - | `-e 'SPOTWEB_DB_HOST=192.168.1.2'` |
| `SPOTWEB_DB_PORT` | The database port. Optional. | 3306 | `-e 'SPOTWEB_DB_PORT=1234'` |
| `SPOTWEB_DB_NAME` | The database used for spotweb. | - | `-e 'SPOTWEB_DB_NAME=spotweb'` |
| `SPOTWEB_DB_USER` | The database server username. | - | `-e 'SPOTWEB_DB_USER=spotweb'` |
| `SPOTWEB_DB_PASS` | The database server password. | - | `-e 'SPOTWEB_DB_PASS=Another-Very~Complex_Password.For+Spotweb'` |
| `SPOTWEB_CRON_RETRIEVE` | [Cron](https://en.wikipedia.org/wiki/Cron) schedule for article retrieval. | - | `-e 'SPOTWEB_CRON_RETRIEVE=*/15 * * * *'` |
| `SPOTWEB_CRON_CACHE_CHECK` | [Cron](https://en.wikipedia.org/wiki/Cron) schedule for article cache sanity check. | - | `-e 'SPOTWEB_CRON_CACHE_CHECK=10 */1 * * *'` |
| `SPOTWEB_BRANCH` | Git Branch to build image with (will do nothing on `docker` run or `docker-compose up`/`start`) | `master` | `--build-arg 'SPOTWEB_BRANCH=develop'` |
| `PHP_VER` | Version of PHP to build image with (will do nothing on `docker run` or `docker-compose up`/`start`) | `7.4` | `--build-arg 'PHP_VER=7.3'` |
### Volumes
| Volume | Function | Default | Example |
| --- | --- | --- | --- |
| `/config` | Spotweb configuration files (not the database) | - | `-v '/my/path/to/configs/spotweb:/config'` |
### Ports
| Port | Function | Default | Example |
| --- | --- | --- | --- |
| `80` | HTTP port to access spotweb front-end | `80` | `-p '4020:80'` |
## License
MIT / BSD
## Author Information
Original Author
[Jeroen Geusebroek](https://jeroengeusebroek.nl/)
Additional Coding
[Alex Wood](https://www.facebook.com/thetewood)
