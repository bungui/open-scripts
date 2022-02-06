#!/usr/bin/env bash

# 下面不生效，注释掉
# set -e

# 参考： https://github.com/Misaka-blog/MisakaLinuxToolbox
# 当前代码地址： https://raw.githubusercontent.com/bungui/open-scripts/dev/client.sh
# 一些全局变量
arch=$(uname -m)
virt=$(systemd-detect-virt)
kernelVer=$(uname -r)
home_dir="/repo"
sudo mkdir -p "$home_dir"
sudo mkdir -p "/usr/lib/systemd/system"

green() {
	echo -e "\033[32m\033[01m$1\033[0m"
}

red() {
	echo -e "\033[31m\033[01m$1\033[0m"
}

yellow() {
	echo -e "\033[33m\033[01m$1\033[0m"
}

if [[ -f /etc/redhat-release ]]; then
	release="Centos"
elif cat /etc/issue | grep -q -E -i "debian"; then
	release="Debian"
elif cat /etc/issue | grep -q -E -i "ubuntu"; then
	release="Ubuntu"
elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
	release="Centos"
elif cat /proc/version | grep -q -E -i "debian"; then
	release="Debian"
elif cat /proc/version | grep -q -E -i "ubuntu"; then
	release="Ubuntu"
elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
	release="Centos"
else
	red "不支持你当前系统，请使用Ubuntu、Debian、Centos的主流系统"
	exit 1
fi

if ! type curl >/dev/null 2>&1; then
	yellow "curl未安装，安装中"
	if [ $release = "Centos" ]; then
		yum -y update && yum install curl -y
	else
		apt-get update -y && apt-get install curl -y
	fi
else
	green "curl已安装"
fi

if ! type wget >/dev/null 2>&1; then
	yellow "wget未安装，安装中"
	if [ $release = "Centos" ]; then
		yum -y update && yum install wget -y
	else
		apt-get update -y && apt-get install wget -y
	fi
else
	green "wget已安装"
fi

if ! type sudo >/dev/null 2>&1; then
	yellow "sudo未安装，安装中"
	if [ $release = "Centos" ]; then
		yum -y update && yum install sudo -y
	else
		apt-get update -y && apt-get install sudo -y
	fi
else
	green "sudo已安装"
fi

# 获取最新的文件，比如：download_script_repo_file "example/backup.sh" "/repo/example/backup.sh"
function download_script_repo_file() {
	script_uri=$1
	dest_path=$2
	last_commit=$(curl -s https://api.github.com/repos/bungui/open-scripts/branches/dev | grep -ioE "\"sha\": \"([a-z0-9]+)\"" | head -1 | awk -F '"' '{print $4}')
	if [ -z "$last_commit" ]; then
		red "获取提交ID失败"
		exit 1
	fi
	echo "最新的提交ID： ${last_commit}"
	script_url="https://raw.githubusercontent.com/bungui/open-scripts/dev/${script_uri}?commit=${last_commit}"
	red "下载地址： ${script_url}"
	if ! sudo wget --quiet --no-cache "$script_url" -O "$dest_path"; then
		red "下载失败，退出"
		exit 1
	fi
	red "下载成功，文件路径： ${dest_path}"
}

function get_public_ip() {
	curl -s myip.ipip.net
}

function get_latest_client_script() {
	client_path="/repo/client.sh"
	download_script_repo_file "client.sh" "$client_path"
	# 禁止敏感信息泄漏
	sudo chmod 700 "$client_path"
	exit 0
}

function install_github_cli() {
	# 参考： https://github.com/cli/cli/blob/trunk/docs/install_linux.md
	if ! type gh >/dev/null 2>&1; then
		yellow "gh未安装，安装中"
		if [ $release = "Centos" ]; then
			sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
			sudo dnf install gh
		else
			curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
			echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
			sudo apt update
			sudo apt install gh -y
		fi
	else
		green "gh已安装，更新中"
		if [ $release = "Centos" ]; then
			sudo dnf update gh
		else
			sudo apt update
			sudo apt install gh -y
		fi
	fi
}

function gh_login() {
	gh auth status
	result=$?
	if [ $result -eq 1 ]; then
		echo "未登陆github"
		gh auth login
	else
		echo "已经登陆"
	fi
}

function check_virtualenv() {

	if [ ! -z "$VIRTUAL_ENV" ]; then
		red "已经在virtualenv中"
		return 1
	fi

	dpkg -s python3-virtualenv
	result=$?
	if [ $result -eq 1 ]; then
		red "未安装python3-virtualenv"
		sudo apt update
		sudo apt install python3 python3-pip python3-virtualenv -y
	fi
	if [ ! -d venv ]; then
		virtualenv venv
	fi
	red "进入python虚拟环境"
	source venv/bin/activate
	red "安装依赖包"
	pip install --upgrade pip
	pip install -r requirements.txt
}

function clone_client_repo() {
	repo_dir="/repo/py-aiohttp-client"
	if [ -d "$repo_dir" ]; then
		red "仓库已经克隆，路径： $repo_dir"
		cd "$repo_dir"
		red "开始更新代码"
		git pull
		check_virtualenv
	else
		cd /repo
		red "开始克隆代码到目录： $repo_dir"
		gh repo clone brilon/py-aiohttp-client
		cd py-aiohttp-client
		check_virtualenv
	fi

}

function install_client_service() {
	cd /repo/py-aiohttp-client
	cp deploy/client.service /usr/lib/systemd/system/aiohttp-client.service
	sudo systemctl daemon-reload
	sudo systemctl enable aiohttp-client.service
	sudo systemctl start aiohttp-client.service
	sudo journalctl -f -u aiohttp-client.service
}

function security_enhance() {

	# 临时修改最大打开文件数
	sudo ulimit -n 8192
	if ! sudo grep -P "soft\s+nofile" /etc/security/limits.conf; then
		red "修改最大打开文件数"
		sudo cat >/etc/security/limits.conf <<-EOF
			*        soft    noproc  10240
			*        hard    noproc  10240
			*        soft    nofile  10240
			*        hard    nofile  10240
			root     soft    noproc  10240
			root     hard    noproc  10240
			root     soft    nofile  10240
			root     hard    nofile  10240
		EOF
	fi

	read -p "修改root密码[y/N]: " confirm
	if [ "$confirm" = "Y" ] || [ "$confirm" = "y" ]; then
		red "开始修改root密码"
		sudo passwd root
	fi

	read -p "增加fg用户[y/N]: " confirm
	if [ "$confirm" = "Y" ] || [ "$confirm" = "y" ]; then
		sudo useradd -m -G sudo -s /bin/bash fg
	fi
	read -p "修改fg用户密码[y/N]: " confirm
	if [ "$confirm" = "Y" ] || [ "$confirm" = "y" ]; then
		red "开始修改fg密码"
		sudo passwd fg
	fi
	read -p "禁止root通过ssh登陆[y/N]: " confirm
	if [ "$confirm" = "Y" ] || [ "$confirm" = "y" ]; then
		sudo sed -i -E "s/PermitRootLogin prohibit-password/PermitRootLogin no/" /etc/ssh/sshd_config
		sudo sed -i -E "s/PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config
		sudo systemctl restart sshd.service
	fi
	read -p "ssh改用55555端口[y/N]: " confirm
	if [ "$confirm" = "Y" ] || [ "$confirm" = "y" ]; then
		sudo sed -i -E "s/^Port 22/Port 55555/" /etc/ssh/sshd_config
		sudo sed -i -E "s/^#Port 22/Port 55555/" /etc/ssh/sshd_config
		sudo systemctl restart sshd.service
	fi
	read -p "是否安装fail2ban[y/N]: " confirm
	if [ "$confirm" = "Y" ] || [ "$confirm" = "y" ]; then
		sudo apt update
		sudo apt install fail2ban -y

		red "sshd登陆失败必须记录日志"
		sudo sed -i 's/#SyslogFacility AUTH/SyslogFacility AUTH/' /etc/ssh/sshd_config
		sudo sed -i 's/#LogLevel INFO/LogLevel INFO/' /etc/ssh/sshd_config
		sudo systemctl restart sshd.service

		red "fail2ban的sshd端口更新为55555"
		sudo sed -i 's/port    = ssh/port    = 55555/' /etc/fail2ban/jail.conf
		sudo sed -i 's/enabled = false/enabled = true/' /etc/fail2ban/jail.conf

		sudo systemctl restart fail2ban
		red "等待fail2ban启动完成"
		sleep 10
		sudo fail2ban-client status
		red "fail2ban sshd状态"
		sudo fail2ban-client status sshd
	fi
}

function install_socks5_proxy() {
	if [ ! -f /usr/bin/brook ]; then
		echo "未安装brook socks5代理，开始安装"
		sudo curl -L https://github.com/txthinking/brook/releases/latest/download/brook_linux_amd64 -o /usr/bin/brook
		sudo chmod +x /usr/bin/brook
	fi
	read -p "输入socks5端口(默认55556): " port
	if [ -z "$port" ]; then
		port="55556"
	fi
	read -p "输入socks5用户名(默认fg): " username
	if [ -z "$username" ]; then
		username="fg"
	fi
	read -p "输入socks5密码(默认741852++): " userpass
	if [ -z "$userpass" ]; then
		userpass="741852++"
	fi
	red "端口为：${port}"
	red "用户名为：${username}"
	red "密码为：${userpass}"
	# <<- 要求制表符不能为空格，必须为TAB
	cat <<-EOF >/usr/lib/systemd/system/socks5.service
		[Unit]
		Description=Brook-socks5
		After=network.target
		Wants=network.target

		[Service]
		WorkingDirectory=/repo
		ExecStart=/usr/bin/brook socks5 --socks5 0.0.0.0:${port} --username ${username} --password "${userpass}"
		Restart=on-abnormal
		RestartSec=5s
		KillMode=mixed

		StandardOutput=null
		StandardError=syslog

		[Install]
		WantedBy=multi-user.target
	EOF
	sudo systemctl daemon-reload
	sudo systemctl enable socks5.service
	sudo systemctl restart socks5.service
	sudo journalctl -u socks5.service
	red "安装socks5服务成功"
}

function install_nginx() {
	if [ ! -f /usr/sbin/nginx ]; then
		red "开始安装nginx"
		sudo apt update
		sudo apt install nginx -y
	else
		red "已安装nginx"
	fi
}

function install_certbot() {
	if [ $release != "Ubuntu" ]; then
		red "非ubuntu系统，不支持certbot安装"
		return 1
	fi
	if [ ! -f /usr/bin/certbot ]; then
		red "开始安装certbot"
		sudo apt-get install snapd -y
		sudo snap install core
		sudo snap refresh core
		sudo snap install --classic certbot
		sudo ln -s /snap/bin/certbot /usr/bin/certbot
	else
		red "已安装certbot"
	fi
}

function install_webdav_server() {
	# 参考：https://github.com/hacdias/webdav
	if [ ! -f /usr/bin/webdav ]; then
		echo "开始安装webdav服务器"
		webdav_tar_path="${home_dir}/linux-amd64-webdav.tar.gz"
		webdav_extract_dir="${home_dir}/webdav"
		sudo wget https://github.com/hacdias/webdav/releases/download/v4.1.1/linux-amd64-webdav.tar.gz -O "$webdav_tar_path"
		sudo mkdir -p "$webdav_extract_dir"
		sudo tar zxvf "$webdav_tar_path" -C "$webdav_extract_dir"
		sudo cp "${webdav_extract_dir}/webdav" /usr/bin/webdav
		sudo rm "$webdav_tar_path" -f
		sudo rm "$webdav_extract_dir" -rf
	else
		echo "已经安装webdav"
	fi

	webdav_config="/opt/webdav.yml"
	if [ ! -f "$webdav_config" ]; then
		sudo mkdir -p /opt
		download_script_repo_file "example/webdav.yml" "$webdav_config"
		red "先手工修改默认配置文件: $webdav_config"
		red "注意需要保证scope的路径存在"
		read -p "按任意建继续" confirm
	fi

	sudo mkdir -p /webdav
	read -p "输入webdav端口(默认55557): " port
	if [ -z "$port" ]; then
		port="55557"
	fi

	webdav_service="/usr/lib/systemd/system/webdav.service"
	# shellcheck disable=SC2024
	sudo cat >"$webdav_service" <<-EOF
		[Unit]
		Description=WebDAV server
		After=network.target

		[Service]
		Type=simple
		User=root
		ExecStart=/usr/bin/webdav --address 127.0.0.1 --port ${port} --config $webdav_config
		Restart=on-failure

		[Install]
		WantedBy=multi-user.target
	EOF
	red "成功生成服务文件： $webdav_service"
	sudo systemctl daemon-reload
	sudo systemctl enable webdav.service
	sudo systemctl restart webdav.service
	sudo journalctl -u webdav.service
	red "安装webdav服务成功"
	red "配置文件地址：/opt/webdav.yml"

	available_path="/etc/nginx/sites-available/webdav"
	enabled_path="/etc/nginx/sites-enabled/webdav"
	if [ ! -f "$available_path" ]; then
		download_script_repo_file "example/nginx-webdav.conf" "$available_path"
		local_url="http://127.0.0.1:${port}"
		sudo sed -i -E "s@http://127.0.0.1:5557@${local_url}@" "$available_path"
		sudo ln -s "$available_path" "$enabled_path"
		red "成功生成默认配置：$available_path"
		read -p "按任意建开始进行修改" confirm
		sudo certbot --nginx
	fi
}

function install_webdav_client() {

	if [ ! -f /usr/bin/rclone ]; then
		echo "开始安装rclone"
		curl https://rclone.org/install.sh | sudo bash
	fi

	if ! sudo rclone listremotes | grep -q hh_webdav 2>/dev/null; then
		red "未发现远程配置：hh_webdav"
		sudo rclone config
	fi

	sudo mkdir -p /data/backup
	# rclone不要使用--allow-other参数，只允许root访问目录
	sudo cat >/usr/lib/systemd/system/rclone.service <<-EOF
		[Unit]
		Description=Rclone Mount
		After=network-online.target

		[Service]
		Type=simple
		ExecStart=/usr/bin/rclone mount hh_webdav:/ /data/backup --cache-dir /tmp --vfs-cache-mode writes --allow-non-empty
		Restart=on-abort

		[Install]
		WantedBy=default.target
	EOF

	sudo systemctl daemon-reload
	sudo systemctl enable rclone.service
	sudo systemctl restart rclone.service
	sudo systemctl status rclone.service
	red "rclone配置完成"
	sudo ls -lh /data/backup
}

function install_backup_cron_job() {
	if [ ! -f /usr/bin/zip ]; then
		red "未安装zip"
		sudo apt update
		sudo apt install zip -y
	fi
	backup_file="/repo/backup.sh"
	if [ ! -f "${backup_file}" ]; then
		download_script_repo_file "example/backup.sh" "${backup_file}"
	else
		read -p "文件已存在，是否覆盖[y/N]: " confirm
		if [ "$confirm" = 'y' ] || [ "$confirm" = 'Y' ]; then
			download_script_repo_file "example/backup.sh" "${backup_file}"
		fi
	fi
	# 包含敏感信息
	sudo chmod 700 "${backup_file}"
	red "修改默认的配置，路径： ${backup_file}"
	read -p "按任意建继续" confirm
	if ! sudo crontab -l | grep -q "${backup_file}"; then
		tmp_file="/tmp/crontab.tmp"
		sudo crontab -l >"${tmp_file}"
		echo "30 5 */1 * * /bin/bash ${backup_file}" >>"${tmp_file}"
		sudo crontab "${tmp_file}"
		sudo rm "${tmp_file}"
	fi
	echo "配置备份定时任务成功"
}

function clone_admin_repo() {
	repo_dir="/repo/py-aiohttp-admin"
	if [ -d "$repo_dir" ]; then
		red "仓库已经克隆，路径： $repo_dir"
		cd "$repo_dir"
		red "开始更新代码"
		git pull
		check_virtualenv
	else
		red "仓库目录不存在，开始克隆"
		cd /repo
		gh repo clone brilon/py-aiohttp-admin
		cd py-aiohttp-admin
		check_virtualenv
	fi
}

function install_redis() {
	if [ -f /usr/bin/redis-cli ]; then
		red "redis已安装"
	else
		sudo apt update
		sudo apt install redis -y
	fi
	red "当前端口情况： "
	ss -ntl | grep --color=auto 6379
}

function install_mysql() {
	if [ -f /usr/bin/mysql ]; then
		red "已安装mariadb-server"
	else
		sudo apt update
		sudo apt install mariadb-server -y
	fi
	read -p "是否进行mysql安全配置[y/N]: " confirm
	if [ "$confirm" = 'y' ] || [ "$confirm" = 'Y' ]; then
		mysql_secure_installation
	fi
	red "当前端口情况： "
	ss -ntl | grep --color=auto 3306
}

function install_admin_service() {
	admin_service="/usr/lib/systemd/system/aiohttp-admin.service"
	repo_dir="/repo/py-aiohttp-admin"
	sudo cat >"$admin_service" <<-EOF
		[Unit]
		Description=aiohttp-admin
		After=network.target
		After=mysqld.service
		After=redis.service
		Wants=network.target

		[Service]
		WorkingDirectory=${repo_dir}
		ExecStart=${repo_dir}/venv/bin/python ${repo_dir}/main.py
		Restart=on-abnormal
		RestartSec=5s
		KillMode=mixed

		StandardOutput=null
		StandardError=syslog

		[Install]
		WantedBy=multi-user.target
	EOF

	sudo systemctl daemon-reload
	sudo systemctl enable aiohttp-admin.service
	sudo systemctl restart aiohttp-admin.service

	available_path="/etc/nginx/sites-available/aiohttp-admin"
	enabled_path="/etc/nginx/sites-enabled/aiohttp-admin"

	if [ ! -f "$available_path" ]; then
		sudo cat >"$available_path" <<-EOF
			server {
				server_name example.com;
				location / {
					proxy_pass http://127.0.0.1:8080;
					proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
					proxy_set_header Host \$http_host;
					proxy_set_header X-Real-IP \$remote_addr;
					proxy_set_header REMOTE-HOST \$remote_addr;
					proxy_redirect off;
					client_max_body_size 20000m;
					proxy_read_timeout 300;
					proxy_connect_timeout 300;
					proxy_send_timeout 300;
				}
			}
		EOF

		red "修改默认的配置: $available_path"
		read -p "按任意键继续" confirm
		sudo ln -s "$available_path" "$enabled_path"
		sudo nginx -s reload

	fi

	read -p "是否申请SSL证书[y/N]" confirm
	if [ "$confirm" = 'y' ] || [ "$confirm" = 'Y' ]; then
		sudo certbot --nginx
	fi

	red "检查日志"
	sudo journalctl -f -u aiohttp-admin.service
}

function disable_ipv6() {
	conf_file="/etc/sysctl.conf"
	# shellcheck disable=SC2002
	if ! cat "$conf_file" | grep -q -i "net.ipv6.conf.all.disable_ipv6=1"; then
		sudo echo "net.ipv6.conf.all.disable_ipv6=1" >>"$conf_file"
		sudo sysctl -p "$conf_file"
		red "成功禁止ipv6"
	else
		red "已禁止ipv6"
	fi
	sudo ifconfig
}

function change_hostname() {
	cur_hostname=$(hostname)
	red "当前主机名: $cur_hostname"
	read -p "输入新的主机名: " new_hostname
	read -p "新的主机名为： ${new_hostname}, 是否确认[y/N] " confirm
	if [ "$confirm" = "Y" ] || [ "$confirm" = "y" ]; then
		sudo echo "$new_hostname" >/etc/hostname
		sed -i -E "/${cur_hostname}\$/d" /etc/hosts
		sudo echo "127.0.0.1 $new_hostname" >>/etc/hosts
	fi
	read -p "是否重启主机 [y/N] " confirm
	if [ "$confirm" = "Y" ] || [ "$confirm" = "y" ]; then
		sudo reboot
	fi
}

function install_tor() {
	if ! dpkg -s tor >/dev/null 2>&1; then
		red "未安装tor，开始安葬"
		sudo apt install tor -y
	else
		red "已安装tor"
	fi
	tor_version=$(tor --version)
	red "tor版本： $tor_version"

	if ! dpkg -s netcat >/dev/null 2>&1; then
		red "未安装netcat，开始安装"
		sudo apt install netcat -y
	else
		red "已安装netcat"
	fi

	read -p "tor控制端口（默认9051）: " tor_port
	if [ -z "$tor_port" ]; then
		tor_port="9051"
	fi
	read -p "tor控制密码（默认123456）： " tor_password
	if [ -z "$tor_password" ]; then
		tor_password="123456"
	fi
	if ! grep -q -i -E "^ControlPort " /etc/tor/torrc; then
		red "写入控制端口： $tor_port"
		sudo echo "ControlPort $tor_port" >>/etc/tor/torrc
	fi
	if ! grep -q -i -E "^ExitNodes " /etc/tor/torrc; then
		sudo echo "ExitNodes {us}" >>/etc/tor/torrc
		sudo echo "StrictNodes 1" >>/etc/tor/torrc
	fi

	if ! grep -q -i -E "^HashedControlPassword " /etc/tor/torrc; then
		red "写入控制密码： $tor_password"
		sudo echo HashedControlPassword $(tor --hash-password "$tor_password" | tail -n 1) >>/etc/tor/torrc
	fi
	sudo systemctl restart tor
	message="echo -e 'AUTHENTICATE \"$tor_password\"' | nc 127.0.0.1 \"$tor_port\""
	red "手工输入命令测试："
	red "$message"
}

# 手工切换tor ip
function change_tor_ip_manually() {
	now_ip=$(torify curl http://api.ipify.org)
	red "切换前的IP： $now_ip"
	echo -e 'AUTHENTICATE "123456"\r\nsignal NEWNYM\r\nQUIT' | nc 127.0.0.1 9051
	now_ip=$(torify curl http://api.ipify.org)
	red "切换后的IP： $now_ip"
}

# 可以把socks5代理变成http代理，并且对referer, cookie进行匿名化
function install_privoxy() {
	if ! dpkg -s privoxy >/dev/null 2>&1; then
		red "未安装privoxy，开始安葬"
		sudo apt install privoxy -y
	else
		red "已安装privoxy"
	fi
	privoxy_config="/etc/privoxy/config"
	if ! grep -q -i -E "^forward-socks5t " "$privoxy_config"; then
		sudo echo "forward-socks5t / 127.0.0.1:9050 ." >>"$privoxy_config"
	fi
	sudo systemctl enable privoxy
	sudo systemctl start privoxy
	red "测试privoxy是否生效："
	curl -x 127.0.0.1:8118 http://api.ipify.org
}

function install_single_tor() {

	tor_socks_port=$1
	tor_control_port=$2
	privoxy_port=$3
	red "socks port:${tor_socks_port}, control port: ${tor_control_port}, privoxy port=${privoxy_port}"

	tor_bin_dir="/var/lib/tor${tor_socks_port}"
	tor_config_file="/etc/tor/torrc${tor_socks_port}"
	tor_service_name="tor${tor_socks_port}.service"
	tor_service="/usr/lib/systemd/system/${tor_service_name}"

	if ! dpkg -s tor >/dev/null 2>&1; then
		red "未安装tor，开始安装"
		sudo apt update
		sudo apt install tor -y
	fi

	if [ ! -d "$tor_bin_dir" ]; then
		cp -r /var/lib/tor "$tor_bin_dir"
		red "拷贝目录成功: $tor_bin_dir"
	fi

	# 每次都重新创建
	sudo cat >"$tor_config_file" <<-EOF
		SocksPort $tor_socks_port
		ControlPort $tor_control_port
		HashedControlPassword 16:78B3D69FE4335BAD60D5DF6BA25F8DF2B755DD9AAD222C42158185230F
		DataDirectory /var/lib/tor${tor_socks_port}
	EOF
	red "写入配置文件： $tor_config_file"

	sudo cat >"$tor_service" <<-EOF
		[Unit]
		Description=tor${tor_socks_port}
		After=network.target
		Wants=network.target

		[Service]
		WorkingDirectory=/var/lib/tor${tor_socks_port}
		ExecStart=/usr/sbin/tor -f ${tor_config_file}
		Restart=on-abnormal
		RestartSec=5s
		KillMode=mixed

		StandardOutput=null
		StandardError=syslog

		[Install]
		WantedBy=multi-user.target
	EOF
	red "写入服务文件: $tor_service"

	sudo systemctl daemon-reload
	sudo systemctl enable "${tor_service_name}"
	sudo systemctl restart "${tor_service_name}"

	sleep 5
	red "验证socks代理： 127.0.0.1:$tor_socks_port"
	curl --proxy socks5h://127.0.0.1:"$tor_socks_port" http://ipinfo.io/ip
	echo
	red "尝试切换IP"
	echo -e 'AUTHENTICATE "123456"\r\nsignal NEWNYM\r\nQUIT' | nc 127.0.0.1 "$tor_control_port"
	sleep 5
	red "切换后的IP： "
	curl --proxy socks5h://127.0.0.1:"$tor_socks_port" http://ipinfo.io/ip
	echo

	if ! dpkg -s privoxy >/dev/null 2>&1; then
		red "未安装privoxy"
		sudo apt update
		sudo apt install privoxy -y
	fi

	privoxy_config_dir="/etc/privoxy${privoxy_port}"
	if [ ! -d "$privoxy_config_dir" ]; then
		sudo cp -a /etc/privoxy "$privoxy_config_dir"
	fi

	privoxy_config_file="${privoxy_config_dir}/config"
	red "privoxy配置文件： ${privoxy_config_file}"
	sudo sed -i -E '/^forward-socks5t /d' "${privoxy_config_file}"
	sudo echo "forward-socks5t / 127.0.0.1:${tor_socks_port} ." >>"${privoxy_config_file}"
	sudo sed -i -E '/^listen-address/d' "${privoxy_config_file}"
	sudo echo "listen-address  127.0.0.1:${privoxy_port}" >>"${privoxy_config_file}"

	privoxy_service_name="privoxy${privoxy_port}.service"
	privoxy_service="/usr/lib/systemd/system/${privoxy_service_name}"
	red "privoxy服务： ${privoxy_service}"
	cat >"${privoxy_service}" <<-EOF
		[Unit]
		Description=Privoxy ${privoxy_port}
		After=network.target

		[Service]
		Environment=PIDFILE=/run/privoxy${privoxy_port}.pid
		Environment=OWNER=privoxy
		Environment=CONFIGFILE=/etc/privoxy${privoxy_port}/config
		Type=forking
		PIDFile=/run/privoxy${privoxy_port}.pid
		ExecStart=/usr/sbin/privoxy --pidfile \$PIDFILE --user \$OWNER \$CONFIGFILE
		ExecStopPost=/bin/rm -f \$PIDFILE
		SuccessExitStatus=15

		[Install]
		WantedBy=multi-user.target
	EOF

	sudo systemctl daemon-reload
	sudo systemctl enable "${privoxy_service_name}"
	sudo systemctl restart "${privoxy_service_name}"

	sleep 5
	red "测试http代理： http://127.0.0.1:${privoxy_port}"
	curl --proxy "http://127.0.0.1:${privoxy_port}" http://ipinfo.io/ip
	echo
}

# 安装多个tor实例
function install_multiple_tor() {
	install_single_tor "9060" "9061" "9062"
	install_single_tor "9070" "9071" "9072"
	install_single_tor "9080" "9081" "9082"
	install_single_tor "9090" "9091" "9092"
	install_single_tor "9100" "9101" "9102"

	install_single_tor "9110" "9111" "9112"
	install_single_tor "9120" "9121" "9122"
	install_single_tor "9130" "9131" "9132"
	install_single_tor "9140" "9141" "9142"
	install_single_tor "9150" "9151" "9152"
}

function add_ssh_config() {
	read -p "输入本地密钥文件名： " private_key_name
	if [ -z "$private_key_name" ]; then
		red "文件名为空"
		return 1
	fi
	read -p "本地用户名（默认为root）： " local_user
	if [ -z "$local_user" ]; then
		local_user="root"
	fi
	if [ "$local_user" = "root" ]; then
		key_dir="/root"
	else
		key_dir="/home/${local_user}"
	fi
	key_dir="${key_dir}/.ssh"
	sudo mkdir -p "$key_dir"
	key_file="${key_dir}/${private_key_name}"
	if ! sudo test -f "$key_file"; then
		red "开始生成密钥到： $key_file"
		sudo ssh-keygen -t rsa -b 2048 -f "$key_file"
	else
		red "密钥已存在： $key_file"
	fi
	sudo chown "${local_user}:${local_user}" "$key_dir" -R
	sudo chmod 600 "$key_dir" -R
	red "开始复制密钥到服务器"
	read -p "输入服务器IP或者域名： " server_ip
	if [ -z "$server_ip" ]; then
		red "服务器IP或域名为空"
		return 1
	fi
	read -p "输入服务器端口（默认为22）: " server_port
	if [ -z "$server_port" ]; then
		server_port="22"
	fi
	read -p "输入用户名： " server_user
	if [ -z "$server_user" ]; then
		red "用户名为空"
		return 1
	fi
	red "复制到： ${server_user}@${server_ip}:${server_port}"
	# 如果已拷贝，会有提示
	sudo ssh-copy-id -i "${key_file}.pub" -p "${server_port}" "${server_user}@${server_ip}"
	config_file="${key_dir}/config"
	if ! sudo grep -q -E -i "Host ${private_key_name}" "$config_file" >/dev/null 2>&1; then
		red "开始配置文件: $config_file"
		sudo tee -a "$config_file" <<-EOF
			Host ${private_key_name}
			  Hostname ${server_ip}
			  Port ${server_port}
			  IdentityFile ${key_file}
			  PubKeyAuthentication yes
			  User ${server_user}
		EOF
	fi
	sudo chown "${local_user}:${local_user}" "$key_dir" -R
	# 目录需要可执行权限
	sudo chmod 700 "${key_dir}"
	# shellcheck disable=SC1009
	# 不能带双引号
	sudo chmod 600 ${key_dir}/*
}

function install_v2ray() {
	v2ray_bin="/usr/local/bin/v2ray"
	v2ray_conf="/usr/local/etc/v2ray/config.json"
	if [ -f "$v2ray_bin" ]; then
		red "已安装v2ray: $v2ray_bin"
	else
		red "开始安装v2ray"
		sudo bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
	fi
	# 弄好配置再启动
	sudo systemctl stop v2ray.service
	sudo systemctl disable v2ray.service
	red "已停止并禁用v2ray"
}

function install_clash() {
	# official: https://github.com/Dreamacro/clash
	download_url="https://github.com/Dreamacro/clash/releases/download/v1.8.0/clash-linux-amd64-v1.8.0.gz"
	clash_bin="/usr/local/bin/clash"
	clash_service="/usr/lib/systemd/system/clash.service"
	clash_config_dir="/etc/clash"
	clash_config="/etc/clash/config.yaml"
	clash_mmdb="/etc/clash/Country.mmdb"
	# official: https://github.com/Dreamacro/maxmind-geoip
	country_mmdb_url="https://github.com/Dreamacro/maxmind-geoip/releases/download/20220112/Country.mmdb"
	if [ ! -f "$clash_bin" ]; then
		red "开始下载clash"
		sudo wget "$download_url" -O $home_dir/clash.gz
		sudo gunzip -c $home_dir/clash.gz >"$clash_bin"
		sudo chmod +x "$clash_bin"
	else
		red "clash已安装"
	fi
	sudo mkdir -p "$clash_config_dir"
	sudo wget "$country_mmdb_url" -O "$clash_mmdb"
	if [ ! -f "$clash_config" ]; then
		red "生成默认的配置文件"

		# 这里未使用dns，因为dns端口如果相同会有冲突
		# journal日志可以忽略：Start DNS server error: missing port in address
		sudo cat >"$clash_config" <<-EOF
			  socks-port: 7891
			  external-controller: 127.0.0.1:9090
			  bind-address: 127.0.0.1
			  dns:
			    enable: false
		EOF
	fi

	sudo cat >"$clash_service" <<-EOF
		[Unit]
		Description=Clash daemon, A rule-based proxy in Go.
		After=network.target

		[Service]
		Type=simple
		Restart=always
		ExecStart=/usr/local/bin/clash -d /etc/clash

		[Install]
		WantedBy=multi-user.target
	EOF

	sudo systemctl daemon-reload
	sudo systemctl enable clash.service
	sudo systemctl restart clash.service

	read -p "是否创建多个实例？[y/N]: " confirm
	if [ "$confirm" == "Y" ] || [ "$confirm" == 'y' ]; then
		socks_ports=(7900 7901 7902 7903 7904 7905 7906 7907 7908 7909)
		api_ports=(9100 9101 9102 9103 9104 9105 9106 9107 9108 9109)
		for ((i = 0; i < ${#socks_ports[@]}; i++)); do
			instance_socks_port=${socks_ports[i]}
			instance_api_port=${api_ports[i]}
			instance_config_dir="/etc/clash${instance_socks_port}"
			if [ -d "$instance_config_dir" ]; then
				red "目录已存在：${instance_config_dir}"
				read -p "是否覆盖[y/N]: " confirm
				if [ "$confirm" != "Y" ] && [ "$confirm" != 'y' ]; then
					red "忽略覆盖"
					continue
				fi
				red "确认覆盖配置：${instance_config_dir}"
			fi
			sudo mkdir -p "${instance_config_dir}"
			instance_config_file="${instance_config_dir}/config.yaml"
			instance_config_mmdb="${instance_config_dir}/Country.mmdb"
			instance_service_name="clash${instance_socks_port}.service"
			instance_service="/usr/lib/systemd/system/${instance_service_name}"
			# 复制mmdb文件
			sudo cp "$clash_mmdb" "$instance_config_mmdb"
			# 初始化config.yaml文件
			sudo cat >"$instance_config_file" <<-EOF
				socks-port: ${instance_socks_port}
				external-controller: 127.0.0.1:${instance_api_port}
				bind-address: 127.0.0.1
				dns:
				  enable: false
			EOF
			# 初始化服务文件
			sudo cat >"$instance_service" <<-EOF
				[Unit]
				Description=Clash daemon ${instance_socks_port} 
				After=network.target

				[Service]
				Type=simple
				Restart=always
				ExecStart=/usr/local/bin/clash -d ${instance_config_dir}

				[Install]
				WantedBy=multi-user.target
			EOF
			sudo systemctl daemon-reload
			sudo systemctl enable ${instance_service_name}
			sudo systemctl start ${instance_service_name}
			sleep 3
			red "日志信息：$instance_service_name"
			sudo journalctl -n 20 -u ${instance_service_name}
		done

	fi

	red "确认监听地址和端口"
	sudo ss -ntl | grep --color=auto -P "78\d{2}|79\d{2}|90\d{2}|91\d{2}"

}

function install_subconverter() {
	# official: https://github.com/tindy2013/subconverter
	# 配置说明： https://github.com/tindy2013/subconverter/blob/master/README-cn.md
	download_url="https://github.com/tindy2013/subconverter/releases/download/v0.7.1/subconverter_linux64.tar.gz"
	subconverter_bin="/repo/subconverter/subconverter"
	tmp_file="/tmp/subconverter.tar.gz"
	# 优先级最高的配置文件
	subconverter_toml="/repo/subconverter/pref.toml"
	subconverter_service="/usr/lib/systemd/system/subconverter.service"
	if [ ! -f "$subconverter_bin" ]; then
		red "开始安装subconverter"
		sudo wget "$download_url" -O "$tmp_file"
		sudo mkdir -p /repo
		sudo tar zxvf "$tmp_file" -C /repo
		sudo rm "$tmp_file"
	else
		red "subconverter已安装"
	fi

	if [ ! -f "$subconverter_toml" ]; then
		sudo mv /repo/subconverter/pref.example.toml "$subconverter_toml"
	fi
	sudo sed -i 's/listen = "0.0.0.0"/listen = "127.0.0.1"/' "$subconverter_toml"

	sudo cat >"$subconverter_service" <<-EOF
		[Unit]
		Description=Subconverter
		After=network.target

		[Service]
		Type=simple
		Restart=always
		ExecStart=$subconverter_bin

		[Install]
		WantedBy=multi-user.target
	EOF

	sudo systemctl daemon-reload
	sudo systemctl enable subconverter.service
	sudo systemctl restart subconverter.service
	sleep 5
	red "确认端口"
	sudo ss -ntl | grep --color=auto -E "25500"
}

function install_docker() {
	if [ ! -f "/usr/bin/docker" ]; then
		red "开始安装docker"
		sudo apt-get update
		sudo apt-get install ca-certificates curl gnupg lsb-release -y
		echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
		       $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
		sudo apt update
		sudo apt-get install docker-ce docker-ce-cli containerd.io -y
	else
		red "已安装docker"
	fi
	if [ ! -f "/usr/local/bin/docker-compose" ]; then
		red "开始安装docker compose"
		sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
	else
		red "已经安装docker compose"
	fi
	red "测试docker hello world"
	sudo docker run hello-world
	red "测试docker curl"
	sudo docker run --rm appropriate/curl -ksI https://www.githubstatus.com/
}

function start_menu() {
	clear
	red "============================"
	yellow "处理器架构：$arch"
	yellow "虚拟化架构：$virt"
	yellow "操作系统：$release"
	yellow "内核版本：$kernelVer"
	red "============================"
	green "下面是工具箱提供的一些功能:"
	echo "1. 安全加固"
	echo "2. 安装github命令行"
	echo "3. 通过gh登陆github"
	echo "4. 克隆或者更新客户端仓库"
	echo "5. 安装client服务"
	echo "6. 安装Brook socks5服务"
	echo "7. 安装nginx"
	echo "8. 安装certbot"
	echo "9. 安装webdav服务"
	echo "10. 安装rclone客户端"
	echo "11. 配置备份任务 "
	echo "12. 克隆或更新admin仓库 "
	echo "13. 安装redis "
	echo "14. 安装mysql "
	echo "15. 安装admin服务 "
	echo "16. 禁止ipv6 "
	echo "17. 修改主机名 "
	echo "18. 安装多个tor实例"
	echo "19. 配置ssh使用公钥登陆 "
	echo "20. 安装v2ray "
	echo "21. 安装clash "
	echo "22. 安装subconverter "
	echo "23. 安装docker "
	echo "v. 更新脚本"
	echo "0. 退出脚本CTRL+C"
	read -p "请输入选项:" menuNumberInput
	case "$menuNumberInput" in
	"1")
		security_enhance
		;;
	"2")
		install_github_cli
		;;
	"3")
		gh_login
		;;
	"4")
		clone_client_repo
		;;
	"5")
		install_client_service
		;;
	"6")
		install_socks5_proxy
		;;
	"7")
		install_nginx
		;;
	"8")
		install_certbot
		;;
	"9")
		install_webdav_server
		;;
	"10")
		install_webdav_client
		;;
	"11")
		install_backup_cron_job
		;;
	"12")
		clone_admin_repo
		;;
	"13")
		install_redis
		;;
	"14")
		install_mysql
		;;
	"15")
		install_admin_service
		;;
	"16")
		disable_ipv6
		;;
	"17")
		change_hostname
		;;
	"18")
		install_multiple_tor
		;;
	"19")
		add_ssh_config
		;;
	"20")
		install_v2ray
		;;
	"21")
		install_clash
		;;
	"22")
		install_subconverter
		;;
	"23")
		install_docker
		;;
	"v")
		get_latest_client_script
		;;
	*)
		red "退出"
		;;
	esac
}

start_menu
