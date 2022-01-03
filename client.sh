#!/usr/bin/env bash

# 参考： https://github.com/Misaka-blog/MisakaLinuxToolbox
# 当前代码地址： https://raw.githubusercontent.com/bungui/open-scripts/dev/client.sh
# 一些全局变量
arch=$(uname -m)
virt=$(systemd-detect-virt)
kernelVer=$(uname -r)
home_dir="/repo"
sudo mkdir -p "$home_dir"

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
	echo "进入python虚拟环境"
	source venv/bin/activate
	yellow "安装依赖包"
	pip install --upgrade pip
	pip install -r requirements.txt
}

function clone_client_repo() {
	if [ -d /repo/py-aiohttp-client ]; then
		echo "仓库已经克隆"
		cd /repo/py-aiohttp-client
		git pull
		check_virtualenv
	else
		mkdir -p /repo
		cd /repo
		gh repo clone brilon/py-aiohttp-client
		cd py-aiohttp-client
		check_virtualenv
	fi

}

function install_task_whois_service() {
	cd /repo/py-aiohttp-client
	cp deploy/task_whois.service /usr/lib/systemd/system/task_whois.service
	sudo systemctl daemon-reload
	sudo systemctl enable task_whois.service
	sudo systemctl start task_whois.service
	sudo journalctl -f -u task_whois.service
}

function security_enhance() {
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
		sudo sed -i -E "s/#Port 22/Port 55555/" /etc/ssh/sshd_config
		sudo systemctl restart sshd.service
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
		# ubuntu 20 lts版本是预装了snap的
		sudo snap install core
		sudo snap refresh core
		sudo snap install --classic certbot
		sudo ln -s /snap/bin/certbot /usr/bin/certbot
	else
		red "已安装certbot"
	fi
}

# shellcheck disable=SC2120
function install_webdav_server() {
	# 参考：https://github.com/hacdias/webdav
	if [ ! -f /usr/bin/webdav ]; then
		echo "开始安装webdav服务器"
		sudo wget https://github.com/hacdias/webdav/releases/download/v4.1.1/linux-amd64-webdav.tar.gz -O "${home_dir}/linux-amd64-webdav.tar.gz"
		sudo mkdir -p "${home_dir}/webdav"
		sudo tar zxvf linux-amd64-webdav.tar.gz -C "${home_dir}/webdav"
		sudo cp "${home_dir}/webdav/webdav" /usr/bin/webdav
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
	sudo cat <<-EOF >/usr/lib/systemd/system/webdav.service
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

	sudo systemctl daemon-reload
	sudo systemctl enable webdav.service
	sudo systemctl restart webdav.service
	sudo journalctl -u webdav.service
	red "安装webdav服务成功"
	red "配置文件地址：/opt/webdav.yml"

	if [ ! -f /etc/nginx/sites-available/webdav ]; then
		sudo cat <<-EOF >/etc/nginx/sites-available/webdav
			server {
			  server_name example.com;
			
			  root /var/www/html;
			  index index.html index.htm index.nginx-debian.html;
			
			  location / {
			    proxy_pass http://127.0.0.1:${port};
			    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
			    proxy_set_header Host \$http_host;
			    proxy_set_header X-Real-IP \$remote_addr;
			          proxy_set_header REMOTE-HOST \$remote_addr;
			    proxy_redirect off;
			    client_max_body_size 20000m;
			  }
			}
		EOF
		sudo ln -s /etc/nginx/sites-available/webdav /etc/nginx/sites-enabled/webdav
		red "成功生成默认配置：/etc/nginx/sites-available/webdav"
		read -p "按任意建开始进行修改" confirm
		sudo certbot --nginx
	fi
}

function install_webdav_client() {

	if [ ! -f /usr/bin/rclone ]; then
		echo "开始安装rclone"
		curl https://rclone.org/install.sh | sudo bash
	fi

	if ! sudo rclone listremotes | grep -q hh_webdav; then
		red "未发现远程配置：hh_webdav"
		sudo rclone config
	fi

	sudo cat <<-EOF >/usr/lib/systemd/system/rclone.service
		[Unit]
		Description=Rclone Mount
		After=network-online.target
		
		[Service]
		Type=simple
		ExecStart=/usr/bin/rclone mount hh_webdav:/ /data/backup --cache-dir /tmp --allow-other --vfs-cache-mode writes --allow-non-empty
		Restart=on-abort
		
		[Install]
		WantedBy=default.target
	EOF

	sudo systemctl daemon-reload
	sudo systemctl enable rclone.service
	sudo systemctl restart rclone.service
	sudo systemctl status rclone.service

	red "rclone配置完成"
}

function install_backup_cron_job() {
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
		echo "30 5 */1 * * /usr/bin/bash ${backup_file}" >>"${tmp_file}"
		sudo crontab "${tmp_file}"
		sudo rm "${tmp_file}"
	fi
	echo "配置备份定时任务成功"
}

function start_menu() {
	clear
	red "============================"
	red "                            "
	red "    AIO Toolbox             "
	echo "                           "
	red "============================"
	yellow "检测到VPS信息如下"
	yellow "处理器架构：$arch"
	yellow "虚拟化架构：$virt"
	yellow "操作系统：$release"
	yellow "内核版本：$kernelVer"
	echo "                            "
	green "下面是工具箱提供的一些功能:"
	echo "1. 安全加固"
	echo "2. 安装github命令行"
	echo "3. 通过gh登陆github"
	echo "4. 克隆或者更新客户端仓库"
	echo "5. 安装task_whois服务"
	echo "6. 安装Brook socks5服务"
	echo "7. 安装nginx"
	echo "8. 安装certbot"
	echo "9. 安装webdav服务"
	echo "10. 安装rclone客户端"
	echo "11. 配置备份任务 "
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
		install_task_whois_service
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
	"v")
		get_latest_client_script
		;;
	*)
		red "退出"
		;;
	esac
}

start_menu
