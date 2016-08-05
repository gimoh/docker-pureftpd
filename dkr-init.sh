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
#
#
# Starts Pure-FTPd server
# All arguments are passed to pureftpd as-is, also processes certain
# environment variables and injects options based on them.  If no
# environment variables are used, pureftpd is called only with command
# line arguments.  See README.md for details.

set -e
set -x


. /etc/profile.d/pure_defaults.sh
PURE_OPTS=""


append_opts() { # OPTS...
  PURE_OPTS="${PURE_OPTS:+${PURE_OPTS} }$*"
}

# Preserve settings stored in environment for shells started with
# `docker exec` and other co-operating containers that use the same
# volumes as ftpd.  This is so that e.g. adduser-ftp script and pure-pw
# use the same settings as the FTPd.
configure() {
  if [[ ! -d "${PURE_CONFDIR}" ]]; then
    mkdir "${PURE_CONFDIR}"
  fi

  printf 'export %s="%s"\n' \
    PURE_DBFILE "${PURE_DBFILE}" \
    PURE_LDAP_CONFIG "${PURE_LDAP_CONFIG}" \
    PURE_MYSQL_CONFIG "${PURE_MYSQL_CONFIG}" \
    PURE_PASSWDFILE "${PURE_PASSWDFILE}" \
    PURE_PGSQL_CONFIG "${PURE_PGSQL_CONFIG}" \
    PURE_VIRT_USER_HOME_PATTERN "${PURE_VIRT_USER_HOME_PATTERN}" \
    > "${PURE_CONFDIR}/pure_settings.sh"
}


# Main

if [[ ! -e "${PURE_CONFDIR}/pure_settings.sh" || configure == "$1" ]]; then
  configure

  # We're running as part of build process to pre-configure things.
  if [[ configure == "$1" ]]; then
    exit 0
  fi
fi

if [[ -n "${PURE_VIRT_USER_HOME_PATTERN}" ]]; then
  PURE_USERS="${PURE_USERS:+${PURE_USERS}+}virt"
fi

orig_ifs="${IFS}"
IFS="${IFS}+"
for opt in ${PURE_USERS}; do
  case ${opt} in
    extauth) append_opts -l "extauth:${PURE_EXTAUTH_SOCKET:?}" ;;
    isolated) append_opts -A -U 177:077 ;;
    ldap) append_opts -l "ldap:${PURE_LDAP_CONFIG}" ;;
    mysql) append_opts -l "mysql:${PURE_MYSQL_CONFIG}" ;;
    noanon) append_opts -E ;;
    pam) append_opts -l pam ;;
    pgsql) append_opts -l "pgsql:${PURE_PGSQL_CONFIG}" ;;
    unix) append_opts -l unix ;;
    virt) append_opts -l "puredb:${PURE_DBFILE}" ;;
    *) echo "Unrecognized PURE_USERS option: '${opt}'" >&2 ;;
  esac
done
IFS="${orig_ifs}"

case "${PURE_IN_CLOUD:-}" in
  docker)
    : ${DOCKERCLOUD_CONTAINER_FQDN:?is the container running in docker cloud?}
    append_opts -P "${DOCKERCLOUD_CONTAINER_FQDN}"
    ;;
  '') : ;;
  *) echo "cloud ${PURE_IN_CLOUD} not supported yet" >&2; exit 2 ;;
esac

/usr/local/sbin/syslog-stdout &

exec /usr/sbin/pure-ftpd ${PURE_OPTS} "$@"
