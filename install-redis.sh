#!/usr/bin/env bash

# system: Debian 10
# command:
# wget -qO- https://raw.githubusercontent.com/bungui/open-scripts/master/install-redis.sh?t=$(date +%s) | bash

set -e
set -x

apt update
apt install redis-server -y

sed -i 's/supervised no/supervised systemd/' /etc/redis/redis.conf
systemctl restart redis-server.service
netstat -ntl
