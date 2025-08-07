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
# 获取 Snell 下载 URL
get_snell_download_url() {
    local version=$1
    local arch=$(uname -m)

    if [ "$version" = "v5" ]; then
        # v5 版本自动拼接下载链接
        case ${arch} in
            "x86_64"|"amd64")
                echo "https://dl.nssurge.com/snell/snell-server-${SNELL_VERSION}-linux-amd64.zip"
                ;;
            "i386"|"i686")
                echo "https://dl.nssurge.com/snell/snell-server-${SNELL_VERSION}-linux-i386.zip"
                ;;
            "aarch64"|"arm64")
                echo "https://dl.nssurge.com/snell/snell-server-${SNELL_VERSION}-linux-aarch64.zip"
                ;;
            "armv7l"|"armv7")
                echo "https://dl.nssurge.com/snell/snell-server-${SNELL_VERSION}-linux-armv7l.zip"
                ;;
            *)
                echo -e "${RED}不支持的架构: ${arch}${RESET}"
                exit 1
                ;;
        esac
    else
        # v4 版本使用 zip 格式
        case ${arch} in
            "x86_64"|"amd64")
                echo "https://dl.nssurge.com/snell/snell-server-${SNELL_VERSION}-linux-amd64.zip"
                ;;
            "i386"|"i686")
                echo "https://dl.nssurge.com/snell/snell-server-${SNELL_VERSION}-linux-i386.zip"
                ;;
            "aarch64"|"arm64")
                echo "https://dl.nssurge.com/snell/snell-server-${SNELL_VERSION}-linux-aarch64.zip"
                ;;
            "armv7l"|"armv7")
                echo "https://dl.nssurge.com/snell/snell-server-${SNELL_VERSION}-linux-armv7l.zip"
                ;;
            *)
                echo -e "${RED}不支持的架构: ${arch}${RESET}"
                exit 1
                ;;
        esac
    fi
}
install_snell() {
    ARCH=$(arch)
    VERSION="v5.0.0"
    SNELL_URL=$(get_snell_download_url "v5")
    INSTALL_DIR="/usr/local/bin"
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