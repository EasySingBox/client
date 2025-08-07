#!/bin/bash

# 检查是否为root下运行
[[ $EUID -ne 0 ]] && echo -e '\033[1;35m请在root用户下运行脚本\033[0m' && exit 1

CENTRAL_API=${1:-""}
RANDOM_PORT_MIN=${2:-10000}
RANDOM_PORT_MAX=${3:-65535}

echo "CENTRAL_API: $CENTRAL_API"
echo "RANDOM_PORT_MIN: $RANDOM_PORT_MIN"
echo "RANDOM_PORT_MAX: $RANDOM_PORT_MAX"

apt install -y git jq gcc wget unzip curl
mkdir /etc/apt/keyrings/ > /dev/null

# install Snell
install_snell() {
    ARCH=$(arch)
    VERSION="v5.0.0"
    SNELL_URL=""
    INSTALL_DIR="/usr/local/bin"
    if [[ ${ARCH} == "aarch64" ]]; then
        SNELL_URL="https://dl.nssurge.com/snell/snell-server-${VERSION}-linux-aarch64.zip"
    else
        SNELL_URL="https://dl.nssurge.com/snell/snell-server-${VERSION}-linux-amd64.zip"
    fi
    wget ${SNELL_URL} -O snell-server.zip
    unzip -o snell-server.zip -d ${INSTALL_DIR}
    rm snell-server.zip
    chmod +x ${INSTALL_DIR}/snell-server
    if ! id "snell" &>/dev/null; then
        useradd -r -s /usr/sbin/nologin snell
    fi

}

install_snell

# install sing-box-beta
curl -fsSL https://sing-box.app/install.sh | sh -s -- --beta

# install hy2-tcp
bash <(curl -fsSL https://tcp.hy2.sh/)

# gen config
bash <(curl -Ls https://codeberg.org/easy-sing-box/client/raw/main/update.sh?_=$(date +%s)) $CENTRAL_API $RANDOM_PORT_MIN $RANDOM_PORT_MAX