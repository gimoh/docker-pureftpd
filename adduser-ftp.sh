#!/bin/sh
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


set -e

: ${PURE_VIRT_USER_HOME_PATTERN:=/srv/ftp/@USER@/./}

# work around an issue where this script is used from interactive shell
# started as "sh" (and not "sh -l") so it doesn't load profile (which
# means it doesn't load PureFTP settings saved in init); this happens
# e.g. when starting a shell from docker cloud web UI
if [[ -z "${PURE_PASSWDFILE}" || -z "${PURE_DBFILE}" ]]; then
  . /etc/profile.d/pure_settings.sh
fi

u_name="${1:?specify username}"
u_home="${PURE_VIRT_USER_HOME_PATTERN//@USER@/${u_name}}"
shift

exec /usr/bin/pure-pw useradd "${u_name}" -u ftpv -D "${u_home}" "$@"
