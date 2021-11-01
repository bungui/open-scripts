#!/usr/bin/env bash

# color
red='\e[91m'
green='\e[92m'
yellow='\e[93m'
magenta='\e[95m'
cyan='\e[96m'
none='\e[0m'

# variables
caddy_arch="amd64"
caddy_tmp="/tmp/install_caddy/"
caddy_tmp_file="/tmp/install_caddy/caddy.tar.gz"
systemd=true

# input

domain=""
path=""
forward_port=""

read -p "input domain(A record points here!!!): " domain
if [ -z "$domain" ]; then
  echo "domain is empty"
  exit 1
fi
read -p "input caddy uri path(like mycontext): " path
if [ -z "$path" ]; then
  echo "path is empty"
  exit 1
fi
read -p "input forward port(like 8080): " forward_port
if [ -z "$forward_port" ]; then
  echo "forward_port is empty"
  exit 1
fi

# download
[[ -d $caddy_tmp ]] && rm -rf $caddy_tmp
if [[ ! ${caddy_arch} ]]; then
  echo -e "$red 获取 Caddy 下载参数失败！$none" && exit 1
fi
caddy_download_link="https://github.com/caddyserver/caddy/releases/download/v1.0.4/caddy_v1.0.4_linux_${caddy_arch}.tar.gz"

mkdir -p $caddy_tmp

if ! wget --no-check-certificate -O "$caddy_tmp_file" $caddy_download_link; then
  echo -e "$red 下载 Caddy 失败！$none" && exit 1
fi

tar zxf $caddy_tmp_file -C $caddy_tmp
cp -f ${caddy_tmp}caddy /usr/local/bin/

if [[ ! -f /usr/local/bin/caddy ]]; then
  echo -e "$red 安装 Caddy 出错！$none" && exit 1
fi

# config service

cp -f ${caddy_tmp}init/linux-systemd/caddy.service /lib/systemd/system/
# sed -i "s/-log-timestamps=false//g" /lib/systemd/system/caddy.service
if [[ ! $(grep "ReadWriteDirectories" /lib/systemd/system/caddy.service) ]]; then
  sed -i "/ReadWritePaths/a ReadWriteDirectories=/etc/ssl/caddy" /lib/systemd/system/caddy.service
fi
sed -i "s/www-data/root/g" /lib/systemd/system/caddy.service

# caddy config

cat >/etc/caddy/Caddyfile <<-EOF
$domain {
    gzip
  	timeouts none
    proxy /${path} https://127.0.0.1:${forward_port} {
        header_upstream Host {host}
		    header_upstream X-Forwarded-Proto {scheme}
		    insecure_skip_verify
    }
}
import sites/*
EOF

# service start
systemctl enable caddy
systemctl restart caddy
ss -ntl
