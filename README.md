[![docker image](https://img.shields.io/docker/stars/gimoh/pureftpd.svg)](https://hub.docker.com/r/gimoh/pureftpd/)

# docker-pureftpd
Pure-FTPD in a docker container

A minimal docker image (based on [alpine](https://hub.docker.com/_/alpine/)) containing Pure-FTPD server (minimal build) and a couple of utility programs/scripts.

Note that this image uses the minimal [`pure-ftpd` package](https://pkgs.alpinelinux.org/package/edge/testing/x86_64/pure-ftpd) included in Alpine, which means LDAP, PostgreSQL (PGSQL) and MySQL support isn't available. There is currently an open request against Alpine to [add another version of pure-ftpd package with all features](https://bugs.alpinelinux.org/issues/7948).

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

PURE_IN_CLOUD:
> Use cloud environment to determine details of passive operation (e.g.
> public IP, ports, etc.); the following values are supported:
>
> - docker: uses `DOCKERCLOUD_CONTAINER_FQDN` variable as passive IP
>   address, unfortunately doesn't support detemining ports
>   automatically yet so `-p` still needs to be passed in

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

Also note you need to add users (as in [Basic usage](#basic-usage) or
[Adding virtual users](#adding-virtual-users) or
[Maintaining virtual users based on JSON config](#maintaining-virtual-users-based-on-json-config)).

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

##### Virtual with automatic maintenance

Here's a full example combining [Virtual only](#virtual-only),
[Volumes](#volumes) and [Maintaining virtual users based on JSON config](#maintaining-virtual-users-based-on-json-config)):

    docker run -d \
      -e PURE_USERS=isolated+noanon+virt \
      -e PURE_VIRT_USER_HOME_PATTERN=/srv/ftp/@USER@/./@USER@ \
      --name=ftpd \
      --volume=/etc/pureftpd \
      --volume=/srv/ftp \
      gimoh/pureftpd \
      -j

    docker run \
      -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION \
      --volumes-from=ftpd
      --rm gimoh/pureftpd-auto-users \
      s3://bucket/key.json

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

### Creating derived image with baked-in users

Normally configuration files are only saved on first start in order to
allow overriding settings with `docker run` options.  If you want to
create user accounts at build time make sure to run
`dkr-init configure` before `adduser-ftp` in your Dockerfile.

This will save settings like location of the password DB which is
needed so that `adduser-ftp` operates on the right database.

Example Dockerfile:

    FROM gimoh/pureftpd

    RUN dkr-init configure \
        && (echo -e 'nooon\nnooon') | adduser-ftp ftpuser -m

Note that if you use that, you should avoid overriding options to do
with config dir or password DB (`PURE_CONFDIR`, `PURE_DBFILE`,
`PURE_PASSWDFILE`) with `--env` options to `docker run`.

### Maintaining virtual users based on JSON config

A companion image `gimoh/pureftpd-auto-users` can be used to maintain
virtual user accounts based on a JSON/YAML config stored on Amazon S3.

The config should have following schema:

    {
      "users": [
        {
          "username": "str",
          "password": "str"
        }
      ]
    }

any other keys in the user dict are ignored.

To be able to use this image, the `ftpd` container needs to have
`/etc/pureftpd` mounted as a volume and then you can run it like:

    docker run \
      -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION \
      --volumes-from=ftpd
      --rm gimoh/pureftpd-auto-users \
      s3://bucket/key.json

The key (filename) needs to have an extension `.json`, `.yml` or
`.yaml`, or alternatively have `Content-Type` in metadata set to
either `application/json` or `application/yaml`.

This will create any accounts that are missing from the database and
remove any that are in database but not in config.  To skip deleting
accounts pass `--no-delete` flag.

There is also `--dry-run` if you just want to see what would have been
done.  To see all options pass `--help`.

    docker run \
      -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION \
      --volumes-from=ftpd
      --rm gimoh/pureftpd-auto-users \
      s3://bucket/key.json \
      --dry-run --no-delete

The S3 bucket setup is outside of scope here, but obviously since this
file contains passwords it should be adequately protected using ACLs or
policies.  I use a dedicated IAM user with attached policy which only
allows read access on that bucket.

### Passive FTP ports

If you want the FTP service to be accessible from outside the host with
the bridge networking, you'll need to publish appropriate ports and
tell Pure-FTPd what address and ports to use.

First of all, you'll need to tell Pure-FTPd what address to tell
clients to connect to when using passive mode using `-P` (force passive
IP) option (by default it will use the container's address which is
private and only accessible from the host).

You also need to choose a range of ports for data channels, say you
want to support 10 concurrent users, pick 10 ports like 30000-30009 and
pass that to `docker run` as `--publish` option as well as `-p`
(passive port range) to `pureftpd`.

Example:

    docker run -d \
      -p 21:21 -p 30000-30009:30000-30009 --name=ftpd \
      gimoh/pureftpd \
      -c 10 -p 30000:30002 -P PUBLIC_DNS_OR_IP

If you're running the container in a cloud environment it may be able
to figure out the public address itself, but you have to indicate
that's what you want by passing env variable `PURE_IN_CLOUD`, e.g.:

    docker run -d \
      -p 21:21 -p 30000-30009:30000-30009 --name=ftpd \
      --env=PURE_IN_CLOUD=docker \
      gimoh/pureftpd \
      -c 10 -p 30000:30002

## Volumes

The Dockerfile doesn't define any volumes as what you may want to
preserve depends on usage and purpose.  The following directories
inside the container are significant:

Path          | Purpose
--------------|--------------------------------------------------------
/etc/pureftpd | this is where password DB lives, mount to preserve users between runs
/var/lib/ftp  | home dir of anonymous user, mount to preserve files uploaded by anonymous
/srv/ftp      | home root of virtual users, mount to preserve files uploaded by virtual users

Plus any other home directories you create if you use
unix/LDAP/mysql/etc. user accounts.

Choose the ones you need and pass them when starting the main ftpd
container, e.g.:

    docker run -d \
      -e PURE_USERS=isolated+noanon+virt \
      -e PURE_VIRT_USER_HOME_PATTERN=/srv/ftp/@USER@/./@USER@ \
      --name=ftpd \
      --volume=/etc/pureftpd \
      --volume=/srv/ftp \
      gimoh/pureftpd \
      -j
