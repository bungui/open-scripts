#!/usr/bin/env bash

# 参考： https://github.com/Misaka-blog/MisakaLinuxToolbox
# 当前代码地址： https://raw.githubusercontent.com/bungui/open-scripts/dev/client.sh
# 一些全局变量
arch=$(uname -m)
virt=$(systemd-detect-virt)
kernelVer=$(uname -r)
home_dir=$(
  cd ~
  pwd
)

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

function update_script() {
  timestamp=$(date +%s)
  wget "https://raw.githubusercontent.com/bungui/open-scripts/dev/client.sh?t=${timestamp}" -O "${home_dir}/client.sh" &&
    chmod -R 777 "${home_dir}/client.sh"
  clear
  bash "${home_dir}/client.sh"
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
      sudo apt install gh
    fi
  else
    green "gh已安装，更新中"
    if [ $release = "Centos" ]; then
      sudo dnf update gh
    else
      sudo apt update
      sudo apt install gh
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
    sudo apt install python3 python3-pip python3-virtualenv
  fi
  if [ ! -d .git ]; then
    red "不是仓库根目录"
    exit 1
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
  read -p "禁止root通过ssh登陆[y/N]: " confirm
  if [ "$confirm" = "Y" ] || [ "$confirm" = "y" ]; then
    sudo sed -i -E "s/PermitRootLogin prohibit-password/PermitRootLogin no/" /etc/ssh/sshd_config
    sudo sed -i -E "s/PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config
    sudo systemctl restart sshd.service
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
  read -p "ssh改用55555端口[y/N]: " confirm
  if [ "$confirm" = "Y" ] || [ "$confirm" = "y" ]; then
    sudo sed -i -E "s/#Port 22/Port 55555/" /etc/ssh/sshd_config
    sudo systemctl restart sshd.service
  fi
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
  echo "v. 更新脚本"
  echo "0. 退出脚本"
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
  "v")
    update_script
    ;;
  *)
    red "退出"
    ;;
  esac
}

start_menu
