#!/usr/bin/env bash

# 参考： https://github.com/Misaka-blog/MisakaLinuxToolbox
# 一些全局变量
arch=$(uname -m)
virt=$(systemd-detect-virt)
kernelVer=$(uname -r)
home_dir=$(cd ~; pwd)

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

function updateScript() {
  wget -N https://raw.githubusercontent.com/bungui/open-scripts/dev/client.sh && chmod -R 777 "$home_dir"/client.sh && bash "$home_dir"/client.sh
}

function start_menu() {
  clear
  red "============================"
  red "                            "
  red "    AIO Toolbox             "
  echo "                           "
  red "  https://aio.pator.fun     "
  echo "                           "
  red "============================"
  yellow "检测到VPS信息如下"
  yellow "处理器架构：$arch"
  yellow "虚拟化架构：$virt"
  yellow "操作系统：$release"
  yellow "内核版本：$kernelVer"
  echo "                            "
  green "下面是工具箱提供的一些功能"
  echo "                            "
  echo "1. 安装github命令行"
  echo "2. 通过gh登陆github"
  echo "                            "
  echo "v. 更新脚本"
  echo "0. 退出脚本"
  echo "                            "
  read -p "请输入选项:" menuNumberInput
  case "$menuNumberInput" in
  1) install_github_cli ;;
  v) updateScript ;;
  0) exit 0 ;;
  esac
}

start_menu