# docker-pureftpd
Pure-FTPD in a docker container

A minimal docker image (based on [alpine](https://hub.docker.com/_/alpine/)) containing Pure-FTPD server (minimal build) and a couple of utility programs/scripts.

## Usage

### Basic usage

Launch:

    docker run -d \
      -p 21:21 -p 30000-30002:30000-30002 --name=ftpd \
      gimoh/pureftpd \
      -c 3 -j -l puredb:/etc/pureftpd.pdb -p 30000:30002

Add users:

    docker exec -it ftpd sh -l
    adduser-ftp bob -m

### Entrypoint

The image uses an entrypoint which passes all arguments to pureftpd
as-is, but also processes certain environment variables and injects
options based on them.  If no environment variables are used, pureftpd
is called only with command line arguments.

Supported environment variables and their effects:

PURE_CONFDIR (default: `/etc/pureftpd`):
> Path to Pure-FTPd configuration directory, used as default location
> for virtual user database; the directory will be created if it does
> not exist

PURE_DBFILE (default: `${PURE_CONFDIR}/passwd.pdb`):
> Path to PureDB indexed database for use with PURE_USERS=virt; see
> Pure-FTPd README.Virtual-Users for more info about PureDB indexed
> files

PURE_EXTAUTH_SOCKET:
> Path to external authentication socket, for use with
> PURE_USERS=extauth; see Pure-FTPd README.Authentication-Modules for
> more info about external authentication

PURE_LDAP_CONFIG (default: `${PURE_CONFDIR}/ldap.conf`):
> Path to LDAP config file for use with PURE_USERS=ldap; see Pure-FTPd
> README.LDAP for more info about LDAP directories

PURE_MYSQL_CONFIG (default: `${PURE_CONFDIR}/mysql.conf`):
> Path to MySQL config file for use with PURE_USERS=mysql; see
> Pure-FTPd README.MySQL for more info about MySQL databases

PURE_PASSWDFILE (default: `${PURE_CONFDIR}/passwd`):
> Path to PureDB passwd-like file (source) for use with PURE_USERS=virt
> see Pure-FTPd README.Virtual-Users for more info about PureDB indexed
> files

PURE_PGSQL_CONFIG (default: `${PURE_CONFDIR}/pgsql.conf`):
> Path to PostreSQL config file for use with PURE_USERS=pgsql; see
> Pure-FTPd README.PGSQL for more info about Postgres databases

PURE_USERS:
> A `+` separated list of keywords:
>
> - extauth: use external authentication handler (expects the handler
>   socket as defined in ${PURE_EXTAUTH_SOCKET})
> - isolated: chroot() everyone, create files without any permissions
>   for group/others (i.e. umask 177/077)
> - ldap: use LDAP directory (expects config file as defined in
>   ${PURE_LDAP_CONFIG} variable)
> - mysql: use MySQL database (expects config file as defined in
>   ${PURE_MYSQL_CONFIG} variable)
> - noanon: prohibit anonymous logins
> - pam: use PAM authentication
> - pgsql: use PostreSQL database (expects config file as defined in
>   ${PURE_PGSQL_CONFIG} variable)
> - unix: unix system users (from /etc/passwd)
> - virt: virtual users (uses password database as defined in
>   ${PURE_DBFILE}
>
> Note: keywords will be processed in order they were specified; this
> matters when chaining authentication methods as each will be tried in
> the same order they were specified.

PURE_VIRT_USER_HOME_PATTERN (default: `/srv/ftp/@USER@/./`):
> Pattern for path to home directories of virtual users; this is used
> by adduser-ftp script when creating virtual FTP users, it will set
> the home directory of a user to this value (with `@USER@` replaced
> with the created user's name); implies PURE_USERS+=virt
>
> Note that this is not the safest as users end up with a writeable `/`
> (and are then able to create files like `/etc/...` and try to trick
> libc into arbitrary code execution), a better pattern is
> `/srv/ftp/@USER@/./@USER@` as then there's only one writeable
> directory in `/` and it's also the default one that's cd'ed into
> after login)

#### Examples

##### Anonymous only

Run with only anonymous login (note that for this to make sense you
need to map or populate the `/var/lib/ftp` volume somehow as it is
read-only by default, it's enough to create a directory owned by `ftp`
user in there):

    docker run -d --name=ftpd --volume=/var/lib/ftp gimoh/pureftpd

##### Virtual only

Run with only virtual users isolated to their home directories and
auto-create their home directories:

    docker run -d \
      -e PURE_USERS=isolated+noanon+virt \
      --name=ftpd \
      gimoh/pureftpd \
      -j

Note that it's better to also use `PURE_VIRT_USER_HOME_PATTERN` like:

    docker run -d \
      -e PURE_USERS=isolated+noanon+virt \
      -e PURE_VIRT_USER_HOME_PATTERN=/srv/ftp/@USER@/./@USER@ \
      --name=ftpd \
      gimoh/pureftpd \
      -j

Also note you need to add users (as in [Basic usage](#basic-usage)).

##### LDAP only

Run with LDAP users only and auto-create home directories:

    docker run -d \
      -e PURE_USERS=ldap+noanon \
      --name=ftpd \
      --volume=/etc/pureftpd \
      gimoh/pureftpd \
      -j

You need to have a file `ldap.conf` in `/etc/pureftpd` volume that
defines LDAP server connection details.

### Adding virtual users

Generally you can add virtual users online from a shell started with:

    docker exec -it ftpd sh -l

The image contains an `adduser-ftp` script that wraps Pure-FTPds
`pure-pw useradd`, setting mapped system user and home directory
according to image conventions and passes remaining options as-is.  The
usage is: `adduser-ftp USERNAME [PURE_PW_USERADD_OPTIONS...]`.

E.g. this creates a user 'bob' mapped to system user 'ftpv', with home
directory set according to `PURE_VIRT_USER_HOME_PATTERN` (defaulting to
`/srv/ftp/bob/./`) and commits the change to the indexed database:

    adduser-ftp bob -m

i.e. it is equivalent to:

    pure-pw useradd bob -u ftpv -d /srv/ftp/bob -m

You can add users with `pure-pw useradd` directly but you'll need to
make sure to set system user and create any necessary directories.
