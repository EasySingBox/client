#!/bin/bash

# 检查是否为root下运行
[[ $EUID -ne 0 ]] && echo -e '\033[1;35m请在root用户下运行脚本\033[0m' && exit 1

# 判断系统并安装依赖
SYSTEM=$(cat /etc/os-release | grep '^ID=' | awk -F '=' '{print $2}' | tr -d '"')
case $SYSTEM in
  "debian"|"ubuntu")
    package_install="apt-get install -y"
    ;;
  "centos"|"oracle"|"rhel")
    package_install="yum install -y"
    ;;
  "fedora"|"rocky"|"almalinux")
    package_install="dnf install -y"
    ;;
  "alpine")
    package_install="apk add"
    ;;
  *)
    echo -e '\033[1;35m暂不支持的系统！\033[0m'
    exit 1
    ;;
esac

nginx="/usr/sbin/nginx"
python3="/usr/bin/python3"
singbox="/usr/bin/sing-box"
xray="/usr/bin/xray"
dkms="/usr/sbin/dkms"
if [ -e "$nginx" ]; then
    echo "nginx 已存在，跳过安装..."
else
    echo "安装 nginx..."
    $package_install nginx
fi
if [ -e "$python3" ]; then
    echo "python 已存在，跳过安装..."
else
    echo "安装 python3 python3-pip python3-venv..."
    $package_install python3 python3-pip python3-venv
fi
if [ -e "$singbox" ]; then
    echo "sing-box 已存在，跳过安装..."
else
    echo "安装 sing-box..."
    bash <(curl -Ls https://github.com/team-cloudchaser/tempest/raw/main/install/singbox.sh)
fi
if [ -e "$xray" ]; then
    echo "xray 已存在，跳过安装..."
else
    echo "安装 xray..."
    bash <(curl -Ls https://github.com/team-cloudchaser/tempest/raw/main/install/xray.sh)
fi
if [ -e "$dkms" ]; then
    echo "tcp-brutal 已存在，跳过安装..."
else
    echo "安装 tcp-brutal..."
    bash <(curl -fsSL https://tcp.hy2.sh/)
fi
echo "重置 venv..."
rm -rf /opt/venv/
cd /opt && mkdir venv
cd /opt/venv && python3 -m venv easy-sing-box
echo "重置 easy-sing-box..."
rm -rf /opt/easy-sing-box/
cd /opt && git clone -q https://github.com/zmlu/easy-sing-box.git > /dev/null 2>&1
cd /opt/easy-sing-box || exit
echo "安装 easy-sing-box 依赖..."
source /opt/venv/easy-sing-box/bin/activate
pip3 install -r requirements.txt
echo "开始生成配置..."
rm -rf /var/www/html/
rm -rf /etc/sing-box/
sysctl -w net.core.rmem_max=16777216 > /dev/null 2>&1
sysctl -w net.core.wmem_max=16777216 > /dev/null 2>&1
python3 generate_config.py