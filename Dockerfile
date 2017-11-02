# docker-pureftpd
# Copyright (C) 2016  gimoh
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

FROM alpine:3.4
MAINTAINER gimoh <gimoh@bitmessage.ch>

ENV PUREFTPD_VERSION=1.0.42 \
    PUREFTPD_SHASUM=5a8e4bd0801331f5f58023ffb586eefea9aa4950 \
    SYSLOG_STDOUT_VERSION=1.1.1 \
    SYSLOG_STDOUT_SHASUM=194c1ec1172dfd822429bfb7a3834f0d97887c15 \
    PURE_CONFDIR=/etc/pureftpd

RUN set -uex \
    && apk add --no-cache --virtual .build-deps \
       curl \
       ca-certificates \
       gcc \
       make \
       musl-dev \
       openssl \
       \
    && cd /tmp \
    && curl -LO https://github.com/timonier/syslog-stdout/releases/download/v"${SYSLOG_STDOUT_VERSION}"/syslog-stdout.tar.gz \
    && echo "${SYSLOG_STDOUT_SHASUM}  syslog-stdout.tar.gz" | sha1sum -c - \
    && install -d -o root -g root -m 755 /usr/local/sbin \
    && tar -C /usr/local/sbin -xzf syslog-stdout.tar.gz \
    \
    && cd /tmp \
    && curl -LO https://download.pureftpd.org/pub/pure-ftpd/releases/pure-ftpd-"${PUREFTPD_VERSION}".tar.gz \
    && echo "${PUREFTPD_SHASUM}  pure-ftpd-${PUREFTPD_VERSION}.tar.gz" | sha1sum -c - \
    && tar -xzf pure-ftpd-"${PUREFTPD_VERSION}".tar.gz \
    \
    && cd /tmp/pure-ftpd-"${PUREFTPD_VERSION}" \
    && ./configure --prefix=/usr \
      --sysconfdir="${PURE_CONFDIR}" \
      --without-humor \
      --without-inetd \
      --with-throttling \
      --with-puredb \
      --with-ftpwho \
    && make install-strip \
    \
    && apk del .build-deps \
    && rm -rf /var/cache/apk/* /tmp/* /var/tmp/*

# user ftpv and /srv/ftp for virtual users, user ftp and /var/lib/ftp
# for anonymous; these are separate so anonymous cannot read/write
# virtual users' files (if both enabled)
RUN adduser -D -h /dev/null -s /etc ftpv \
    && install -d -o root -g root -m 755 ~ftp /srv/ftp

COPY pure_defaults.sh /etc/profile.d/
COPY dkr-init.sh /usr/local/sbin/dkr-init
COPY adduser-ftp.sh /usr/local/bin/adduser-ftp

ENTRYPOINT ["/usr/local/sbin/dkr-init"]
