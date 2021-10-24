#!/usr/bin/env bash

redis_ver=6.2.6
download_dir=/down/redis

mkdir -p ${download_dir}
cd ${download_dir}

wget https://download.redis.io/releases/redis-${redis_ver}.tar.gz -O redis-${redis_ver}.tar.gz
tar xzf redis-${redis_ver}.tar.gz

make -j $(nproc)
make install