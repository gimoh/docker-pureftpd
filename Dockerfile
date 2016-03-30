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

FROM alpine:3.3
MAINTAINER gimoh <gimoh@bitmessage.ch>

RUN printf '%s\n' \
      '@testing http://dl-cdn.alpinelinux.org/alpine/edge/testing' \
      >> /etc/apk/repositories \
    && apk add --update pure-ftpd@testing=1.0.42-r0 && rm -rf /var/cache/apk/*

# user ftpv and /srv/ftp for virtual users, user ftp and /var/lib/ftp
# for anonymous; these are separate so anonymous cannot read/write
# virtual users' files (if both enabled)
RUN adduser -D -h /dev/null -s /etc ftpv \
    && install -d -o root -g root -m 755 ~ftp /srv/ftp

COPY dkr-init.sh /usr/local/sbin/dkr-init

ENTRYPOINT ["/usr/local/sbin/dkr-init"]
