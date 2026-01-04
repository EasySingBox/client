#!/bin/bash

# 检查是否为root下运行
[[ $EUID -ne 0 ]] && echo -e '\033[1;35m请在root用户下运行脚本\033[0m' && exit 1

RANDOM_PORT_MIN=${1:-10000}
RANDOM_PORT_MAX=${2:-65535}

echo "RANDOM_PORT_MIN: $RANDOM_PORT_MIN"
echo "RANDOM_PORT_MAX: $RANDOM_PORT_MAX"

apt install -y git jq gcc wget unzip curl
mkdir /etc/apt/keyrings/ > /dev/null

sudo apt remove -y sing-box

# install sing-box-beta
curl -fsSL https://sing-box.app/install.sh | sh -s -- --beta

# gen config
bash <(curl -Ls https://raw.githubusercontent.com/EasySingBox/client/main/update.sh?_=$(date +%s)) $RANDOM_PORT_MIN $RANDOM_PORT_MAX