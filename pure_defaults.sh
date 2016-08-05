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


# Load settings saved by main ftpd container on init
if [[ -e "${PURE_CONFDIR}/pure_settings.sh" ]]; then
  . "${PURE_CONFDIR}/pure_settings.sh"
fi

# Defaults
# This is for situations when pure_settings.sh doesn't exist (yet).
# PURE_CONFDIR default value is set in Dockerfile so it's available
# globally (run, exec, etc.), these are set here because they are
# derived from PURE_CONFDIR and we want those changes to propagate (on
# the first run anyways).
: ${PURE_DBFILE:=${PURE_CONFDIR}/passwd.pdb} \
  ${PURE_LDAP_CONFIG:=${PURE_CONFDIR}/ldap.conf} \
  ${PURE_MYSQL_CONFIG:=${PURE_CONFDIR}/mysql.conf} \
  ${PURE_PASSWDFILE:=${PURE_CONFDIR}/passwd} \
  ${PURE_PGSQL_CONFIG:=${PURE_CONFDIR}/pgsql.conf}

# Mark variables for export so they can be accessed by subprocesses
export PURE_CONFDIR PURE_DBFILE PURE_LDAP_CONFIG PURE_MYSQL_CONFIG \
  PURE_PASSWDFILE PURE_PGSQL_CONFIG PURE_VIRT_USER_HOME_PATTERN
