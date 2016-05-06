#!/usr/bin/env python3
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


"""Auto FTP user accounts.

Automatically synchronizes (creates/removes) PureFTP virtual user
accounts with definition in JSON config file stored on Amazon S3.

The config should have following schema:

  {
    "users": [
      {
        "username": "str",
        "password": "str"
      }
    ]
  }

Usage:
  auto-users [options] S3_URI

Options:
  -h --help       This help text
  -d --dry-run    only show what accounts would be created
  -D --no-delete  do not delete accounts even if they don't exist in config
"""

import os

import boto3

from operator import itemgetter
from pipes import quote
from subprocess import CalledProcessError
from urllib.parse import urlparse

from docopt import docopt
from shell import instream, p


# TODO: might be useful to separate out some of those classes into a
#       re-usable library

class S3Uri:
    """Represents an S3 URI

    Can be created by passing a bucket name and key or using the
    L{parse} method to parse a URI.
    
    Provides access to 2 properties: C{bucket} and C{key}.
    """
    def __init__(self, bucket, key):
        self.bucket = bucket
        self.key = key

    @classmethod
    def parse(cls, s):
        """Parse string as an S3 url

        Handles 4 styles of S3 URLs (official and s3cmd style):

            >>> S3Uri.parse('bucket/key')
            S3Uri(bucket='bucket', key='key')
            >>> S3Uri.parse('s3://my-bucket/some/path.txt')
            S3Uri(bucket='my-bucket', key='some/path.txt')
            >>> S3Uri.parse('https://s3.amazonaws.com/some-bucket/file.txt')
            S3Uri(bucket='some-bucket', key='file.txt')
            >>> S3Uri.parse('http://buck.s3.amazonaws.com/the/file.txt')
            S3Uri(bucket='buck', key='the/file.txt')
        """
        # Based on:
        # https://github.com/fordhurley/s3url/blob/master/s3url/s3.py
        s = s[5:] if s.startswith('s3://') else s
        if s.startswith('http:') or s.startswith('https:'):
            url = urlparse(s)
            if url.netloc == 's3.amazonaws.com':
                path = url.path[1:]  # remove leading slash
                bucket, key = path.split('/', 1)
            else:
                # bucket.s3.amazonaws.com style
                bucket = url.netloc.split('.', 1)[0]
                key = url.path[1:]
        else:
            bucket, key = s.split('/', 1)
        return cls(bucket, key)

    def to_url(self):
        """Return an S3 url for this S3 object
        """
        # TODO: implement, maybe base on:
        #       https://github.com/Jaza/url-for-s3/blob/master/url_for_s3.py
        return 's3://{}/{}'.format(self.bucket, self.key)

    def __repr__(self):
        return '{}(bucket={!r}, key={!r})'.format(
            self.__class__.__name__, self.bucket, self.key)


class S3Config:
    """Provides access to configuration data stored on S3

    This can be a JSON or YAML object.  Calling C{get} method will
    fetch the data, parse it and return a data structure.
    """
    # Based on:
    # https://bitbucket.org/jibbolo/s3config/src/81fe461ea6c8/s3config/__init__.py?at=master
    def __init__(self, uri):
        """
        :param uri: an S3Uri instance representing the S3 object URI
        :type uri: S3Uri
        """
        self.uri = uri

    def get(self):
        obj = self._fetch()
        ctype = self._get_content_type(obj)
        data = self._get_body(obj)
        parse = self._get_parser(ctype)
        return parse(data)

    def _fetch(self):
        s3 = boto3.resource('s3')
        obj = s3.Object(self.uri.bucket, self.uri.key)
        obj.load()
        return obj

    @staticmethod
    def _get_body(obj):
        return obj.get()['Body'].read().decode('utf-8')

    @staticmethod
    def _get_content_type(obj):
        """Return content type (format) of the given object

        Will try to use a suffix (extension) of the filename, or
        content-type header of the returned object.

        :returns: str, one of 'application/json' or 'application/yaml'
        """
        try:
            suffix = os.path.splitext(obj.key)[1].replace('.', '')
            if suffix == 'json':
                return 'application/json'
            elif suffix in ('yml', 'yaml'):
                return 'application/yaml'
            else:
                raise IndexError()
        except IndexError:
            return obj.content_type

    @staticmethod
    def _get_parser(content_type):
        if content_type == 'application/json':
            import json
            return json.loads
        elif content_type in ('application/yaml', 'application/x-yaml'):
            import yaml
            return yaml.load
        else:
            raise ValueError('Unsupported type: {}'.format(content_type))


def _check_call(proc):
    """
    :type proc: shell.RunCmd
    :raises: CalledProcessError if returncode != 0
    """
    if proc.re() != 0:
        raise CalledProcessError(
            proc.re(), proc.cmd_str,
            proc.stdout().decode('utf-8'), proc.stderr().decode('utf-8'))
    return proc


class PurePW:
    """Represents a PureFTP password database"""
    def commit(self):
        """Commit any changes to the binary DB file"""
        _check_call(p('pure-pw mkdb'))

    def list(self):
        """A list of usernames currently in the password database"""
        try:
            proc = _check_call(p('pure-pw list'))
            out = proc.stdout().decode('utf-8')
        except CalledProcessError as e:
            if e.returncode != 2 or \
                'Unable to open the passwd file:' not in e.stderr:
                raise
            # DB doesn't exist, so no users
            out = ''

        return [l.split('\t')[0] for l in out.splitlines()]

    def adduser(self, username, password):
        """Add a virtual FTP user to PureFTP database"""
        # need to pass a string like 'password\npassword\n'
        pw_str = '\n'.join([password]*2 + [''])
        proc = instream(pw_str).p('adduser-ftp {}'.format(quote(username)))
        _check_call(proc)

    def deluser(self, username):
        """Remove a virtual FTP user from PureFTP database"""
        _check_call(p('pure-pw userdel {}'.format(quote(username))))


def sync_users(users, dry_run=False, no_delete=False):
    """Sync (add/remove) FTP users in the DB to the specified list

    :param users: a list of user info dicts containing at least keys:
        username, password
    :param dry_run: if True only print what would have been done
    :param no_delete: if True do not delete accounts which are in DB
        but not in the C{users} list
    """
    pw = PurePW()
    existing = pw.list()

    to_add = [u for u in users if u['username'] not in existing]
    to_rm = [
        u for u in existing if u not in map(itemgetter('username'), users)]

    add = pw.adduser if not dry_run else lambda u, p: None
    rm = pw.deluser if not dry_run else lambda u: None
    commit = pw.commit if not dry_run else lambda: None

    def try_do(func, ok_msg, fail_msg, *args):
        try:
            func(*args)
        except Exception as e:
            print(fail_msg.format(*args, exc=e))
        else:
            print(ok_msg.format(*args))

    for user, passwd in map(itemgetter('username', 'password'), to_add):
        try_do(add, 'added "{}"', 'failed to add "{}": {exc}', user, passwd)

    if no_delete:
        commit()
        if to_rm:
            print('skipping deletion of following users: {}'.format(
                ', '.join(to_rm)))
        return

    for user in to_rm:
        try_do(rm, 'removed "{}"', 'failed to remove "{}": {exc}', user)

    commit()


def main_s3uri():  # demo for S3Uri
    test_uris = (
        'bucket/key',
        's3://my-bucket/some/path.txt',
        'https://s3.amazonaws.com/some-bucket/file.txt',
        'http://buck.s3.amazonaws.com/the/file.txt'
    )
    for s in test_uris:
        u = S3Uri.parse(s)
        print('{:50} {!r:50} {}'.format(s, u, u.to_url()))


def main_s3config():  # demo for S3Config
    args = docopt(__doc__, version='0.1')
    print(args)

    uri = S3Uri.parse(args['S3_URI'])
    cfgfile = S3Config(uri)

    print('config object:\n---')
    obj = cfgfile._fetch()
    print('url: {}'.format(uri.to_url()))
    print('content_type: {}'.format(cfgfile._get_content_type(obj)))
    print('--- # raw:')
    print(cfgfile._get_body(obj))
    print('--- # parsed:')
    import pprint
    pprint.pprint(cfgfile.get())


def main():
    args = docopt(__doc__, version='0.1')

    uri = S3Uri.parse(args['S3_URI'])
    cfg = S3Config(uri).get()

    sync_users(
        cfg['users'],
        dry_run=args['--dry-run'],
        no_delete=args['--no-delete']
    )


if __name__ == '__main__':
    #main_s3uri()
    #main_s3config()
    main()
