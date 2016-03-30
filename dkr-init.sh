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


# Defaults
: ${PURE_CONFDIR:=/etc/pureftpd} \
  ${PURE_DBFILE:=${PURE_CONFDIR}/passwd.pdb} \
  ${PURE_LDAP_CONFIG:=${PURE_CONFDIR}/ldap.conf} \
  ${PURE_MYSQL_CONFIG:=${PURE_CONFDIR}/mysql.conf} \
  ${PURE_PASSWDFILE:=${PURE_CONFDIR}/passwd} \
  ${PURE_PGSQL_CONFIG:=${PURE_CONFDIR}/pgsql.conf}
PURE_OPTS=""


append_opts() { # OPTS...
  PURE_OPTS="${PURE_OPTS:+${PURE_OPTS} }$*"
}


# Main

if [[ ! -d ${PURE_CONFDIR} ]]; then
  mkdir "${PURE_CONFDIR}"
fi

if [[ ${PURE_VIRT_USER_HOME_PATTERN} ]]; then
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

# Save location of virt user password database, for the deamon as well
# as for adduser-ftp script and pure-pw run from interactive shell
# started via `docker exec -it this_container sh -l`
export PURE_PASSWDFILE PURE_DBFILE
printf 'export %s="%s"\n' \
  PURE_PASSWDFILE "${PURE_PASSWDFILE}" \
  PURE_DBFILE "${PURE_DBFILE}" \
  > /etc/profile.d/pure_settings.sh

exec /usr/sbin/pure-ftpd ${PURE_OPTS} "$@"
