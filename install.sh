#!/bin/bash

# 检查是否为root下运行
[[ $EUID -ne 0 ]] && echo -e '\033[1;35m请在root用户下运行脚本\033[0m' && exit 1

apt install -y git
apt install -y nginx
apt install -y jq
mkdir /etc/apt/keyrings/ > /dev/null
# sing-box-beta
sudo curl -fsSL https://sing-box.app/gpg.key -o /etc/apt/keyrings/sagernet.asc
sudo chmod a+r /etc/apt/keyrings/sagernet.asc
echo "deb [arch=`dpkg --print-architecture` signed-by=/etc/apt/keyrings/sagernet.asc] https://deb.sagernet.org/ * *" | \
  sudo tee /etc/apt/sources.list.d/sagernet.list > /dev/null
sudo apt update
sudo apt install sing-box-beta
echo "重置 warp..."
bash <(curl -fsSL git.io/warp.sh) x

bash <(curl -Ls https://github.com/zmlu/easy-sing-box/raw/main/update.sh?_=$(date +%s)) $1