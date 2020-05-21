FROM ubuntu:20.04
MAINTAINER Jeroen Geusebroek <me@jeroengeusebroek.nl>, Alex Wood <github@alex-wood.org.uk>

ENV PHP_VER=${PHP_VER:-7.4}
ARG DEBIAN_FRONTEND="noninteractive"
ENV TERM="xterm-color"
ARG APTLIST="apache2 php${PHP_VER} php${PHP_VER}-curl php${PHP_VER}-gd php${PHP_VER}-gmp php${PHP_VER}-mysql php${PHP_VER}-pgsql php${PHP_VER}-xml php${PHP_VER}-xmlrpc php${PHP_VER}-mbstring php${PHP_VER}-zip git cron wget jq"

# This could be an ENV and then use it to update repo on every restart of the container,
# but the .git dir is removed further down
ARG SPOTWEB_BRANCH=${SPOTWEB_BRANCH:-"master"}
ENV REFRESHED_AT='2020-05-21'

RUN apt-get -qy update && \
    apt-get -qy dist-upgrade && \
    apt-get -qy install software-properties-common
RUN echo "force-unsafe-io" > /etc/dpkg/dpkg.cfg.d/02apt-speedup &&\
    echo "Acquire::http {No-Cache=True;};" > /etc/apt/apt.conf.d/no-cache && \
    add-apt-repository -yu ppa:git-core/ppa && \
    add-apt-repository -yu ppa:ondrej/apache2 && \
    add-apt-repository -yu ppa:ondrej/php && \
    apt-get -qy update && \
    apt-get install -qy $APTLIST && \
    \
    # Cleanup
    apt-get -y autoremove && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -r /var/www/html && \
    rm -rf /tmp/*

RUN git clone -b ${SPOTWEB_BRANCH} --single-branch https://github.com/spotweb/spotweb.git /var/www/spotweb && \
    rm -rf /var/www/spotweb/.git && \
    chmod -R 775 /var/www/spotweb && \
    chown -R www-data:www-data /var/www/spotweb

COPY ./entrypoint.sh /entrypoint.sh
RUN chmod u+x /entrypoint.sh

COPY files/000-default.conf /etc/apache2/sites-enabled/000-default.conf

# Add caching and compression config to .htaccess
COPY files/001-htaccess.conf .
RUN cat /001-htaccess.conf >> /var/www/spotweb/.htaccess
RUN rm /001-htaccess.conf

VOLUME [ "/config" ]

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]

HEALTHCHECK --interval=300s --timeout=30s CMD curl --fail http://localhost:80 || exit 1
