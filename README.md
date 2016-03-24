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
    pure-pw useradd bob -u ftp -d ~ftp/./bob -m
