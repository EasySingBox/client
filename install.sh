#!/bin/bash

# 检查是否为root下运行
[[ $EUID -ne 0 ]] && echo -e '\033[1;35m请在root用户下运行脚本\033[0m' && exit 1

# 檢查是否提供了第一個參數
if [ -z "$1" ]; then
    echo "錯誤：第一個參數 CENTRAL_API 必須填寫！"
    echo "使用方式: bash <(curl -Ls https://codeberg.org/easy-sing-box/client/raw/main/install.sh) <CENTRAL_API> [RANDOM_PORT_MIN] [RANDOM_PORT_MAX]"
    exit 1
fi

CENTRAL_API=${1:-""}
RANDOM_PORT_MIN=${2:-10000}
RANDOM_PORT_MAX=${3:-65535}

echo "CENTRAL_API: $CENTRAL_API"
echo "RANDOM_PORT_MIN: $RANDOM_PORT_MIN"
echo "RANDOM_PORT_MAX: $RANDOM_PORT_MAX"

apt install -y git
apt install -y jq
mkdir /etc/apt/keyrings/ > /dev/null
# sing-box-beta
bash <(curl -fsSL https://codeberg.org/easy-sing-box/tools/raw/main/deb-install-beta.sh)
bash <(curl -Ls https://codeberg.org/easy-sing-box/client/raw/main/update.sh?_=$(date +%s)) $CENTRAL_API $RANDOM_PORT_MIN $RANDOM_PORT_MAX