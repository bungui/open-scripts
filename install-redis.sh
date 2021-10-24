#!/usr/bin/env bash

# system: Debian 10
# command:
# wget -qO- https://raw.githubusercontent.com/bungui/open-scripts/master/install-redis.sh?t=$(date +%s) | bash

set -e
set -x

redis_ver=6.2.6
download_dir=/down/redis

apt update
apt install build-essential pkg-config tcl -y

mkdir -p ${download_dir}
cd ${download_dir}

wget https://download.redis.io/releases/redis-${redis_ver}.tar.gz -O redis-${redis_ver}.tar.gz
tar xzf redis-${redis_ver}.tar.gz
cd redis-${redis_ver}

make -j $(nproc)
# disable test. cos no enough memory
# make test
make install
