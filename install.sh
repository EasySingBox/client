#!/bin/bash

# 检查是否为root下运行
[[ $EUID -ne 0 ]] && echo -e '\033[1;35m请在root用户下运行脚本\033[0m' && exit 1

apt-get install -y nginx python3 python3-pip python3-venv
mkdir /etc/apt/keyrings/
# sing-box-beta
sudo curl -fsSL https://sing-box.app/gpg.key -o /etc/apt/keyrings/sagernet.asc
sudo chmod a+r /etc/apt/keyrings/sagernet.asc
echo "deb [arch=`dpkg --print-architecture` signed-by=/etc/apt/keyrings/sagernet.asc] https://deb.sagernet.org/ * *" | \
  sudo tee /etc/apt/sources.list.d/sagernet.list > /dev/null
sudo apt-get update
sudo apt-get install sing-box-beta
echo "重置 warp..."
bash <(curl -fsSL git.io/warp.sh) x
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
python3 generate_config.py