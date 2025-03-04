#!/bin/bash

# 检查是否为root下运行
[[ $EUID -ne 0 ]] && echo -e '\033[1;35m请在root用户下运行脚本\033[0m' && exit 1

apt install -y git
apt install -y nginx
apt install -y jq
apt install -y python3
apt install -y python3-pip
apt install -y python3-pip
apt install -y python3-venv
apt install -y openresolv
apt install -y resolvconf
mkdir /etc/apt/keyrings/ > /dev/null
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
mkdir /opt/venv > /dev/null
rm -rf /opt/venv/easy-sing-box
cd /opt/venv && python3 -m venv easy-sing-box
echo "重置 easy-sing-box..."
rm -rf /opt/easy-sing-box/
cd /opt && git clone https://github.com/zmlu/easy-sing-box.git
cd /opt/easy-sing-box || exit
echo "安装 easy-sing-box 依赖..."
source /opt/venv/easy-sing-box/bin/activate
pip3 install -r requirements.txt
echo "开始生成配置..."
config_file="$HOME/esb.config"
www_dir_random_id=$(jq -r '.www_dir_random_id' "$config_file")
rm -rf /var/www/html/${www_dir_random_id}
rm -rf /etc/sing-box/
python3 generate_config.py $1