#!/usr/bin/env bash

# 一些全局变量
ver="1.4.5"
changeLog="新增禁用Oracle系统自带防火墙、Acme.sh和Screen后台任务管理脚本"
arch=$(uname -m)
virt=$(systemd-detect-virt)
kernelVer=$(uname -r)

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

function start_menu() {
  clear
  red "============================"
  red "                            "
  red "    AIO Toolbox             "
  echo "                           "
  red "  https://aio.pator.fun     "
  echo "                           "
  red "============================"
  echo "                            "
  green "检测到您当前运行的工具箱版本是：$ver"
  green "更新日志：$changeLog"
  echo "                            "
  yellow "检测到VPS信息如下"
  yellow "处理器架构：$arch"
  yellow "虚拟化架构：$virt"
  yellow "操作系统：$release"
  yellow "内核版本：$kernelVer"
  echo "                            "
  green "下面是工具箱提供的一些功能"
  echo "                            "
  echo "1. VPS修改登录方式为root密码登录"
  echo "2. VPS安装warp"
  echo "3. X-ui面板安装"
  echo "4. Mack-a 节点配置脚本"
  echo "                            "
  echo "5. 一键开启BBR"
  echo "6. 安装宝塔开心版"
  echo "7. 一键安装docker"
  echo "8. 流媒体解锁测试"
  echo "                            "
  echo "9. VPS三网测速"
  echo "10. 修改主机名"
  echo "11. 安装可乐大佬的ServerStatus-Horatu探针"
  echo "12. hijk大佬的v2脚本，支持IBM LinuxONE s390x的机器搭建节点"
  echo "                            "
  echo "13. 一键安装 Telegram MTProxy 代理服务器"
  echo "14. Acme.sh 证书申请脚本"
  echo "15. Screen 后台运行管理脚本"
  echo "16. 禁用Oracle（甲骨文）系统自带防火墙"
  echo "                            "
  echo "v. 更新脚本"
  echo "0. 退出脚本"
  echo "                            "
  read -p "请输入选项:" menuNumberInput
  case "$menuNumberInput" in
  1) rootLogin ;;
  2) warp ;;
  3) xui ;;
  4) macka ;;
  5) bbr ;;
  6) bthappy ;;
  7) docker ;;
  8) mediaUnblockTest ;;
  9) vpsSpeedTest ;;
  10) changehostname ;;
  11) serverstatus ;;
  12) hijk ;;
  13) tgMTProxy ;;
  v) updateScript ;;
  0) exit 0 ;;
  esac
}

start_menu
