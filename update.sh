#!/bin/bash

# 检查是否为root下运行
[[ $EUID -ne 0 ]] && echo -e '\033[1;35m请在root用户下运行脚本\033[0m' && exit 1

# 檢查是否提供了第一個參數
if [ -z "$1" ]; then
    echo "錯誤：第一個參數 CENTRAL_API 必須填寫！"
    echo "使用方式: bash <(curl -Ls https://codeberg.org/easy-sing-box/client/raw/main/update.sh) <CENTRAL_API> [RANDOM_PORT_MIN] [RANDOM_PORT_MAX]"
    exit 1
fi

echo "开始生成配置..."

CONFIG_FILE="$HOME/esb.config"
SING_BOX_CONFIG_DIR="/etc/sing-box"
NGINX_WWW_DIR="/var/www/html"
CENTRAL_API="$1"
MIN=${2:-10000}
MAX=${3:-65535}
echo "CENTRAL_API: $CENTRAL_API"
echo "RANDOM_PORT_MIN: $MIN"
echo "RANDOM_PORT_MAX: $MAX"
function get_ip_info() {
    IP_INFO=$(curl -s -4 ip.network/more)
    SERVER_IP=$(echo "$IP_INFO" | jq -r .ip)
    COUNTRY=$(echo "$IP_INFO" | jq -r .country)
    VPS_ORG=$(echo "$IP_INFO" | jq -r .asOrganization)
}

function generate_reality_keys() {
    XRAY_OUT=$(sing-box generate reality-keypair)
    PRIVATE_KEY=$(echo "$XRAY_OUT" | grep "PrivateKey" | awk '{print $2}')
    PUBLIC_KEY=$(echo "$XRAY_OUT" | grep "PublicKey" | awk '{print $2}')
}

function generate_reality_sid() {
    REALITY_SID=$(sing-box generate rand 4 --hex | tr -d '\n')
}

function generate_password() {
    PASSWORD=$(sing-box generate uuid | tr -d '\n')
    H2_OBFS_PASSWORD=$(sing-box generate uuid | tr -d '\n')
}

function generate_port() {
    # 定義範圍

    # 用陣列來儲存隨機數
    numbers=()

    # 迴圈生成 4 個不重複的隨機數
    while [ ${#numbers[@]} -lt 4 ]; do
        # 生成範圍內的隨機數
        num=$((RANDOM % ($MAX - $MIN + 1) + $MIN))

        # 檢查是否已存在該數字
        if [[ ! " ${numbers[@]} " =~ " $num " ]]; then
            numbers+=($num)
        fi
    done

    # 將隨機數賦值給變量
    H2_PORT=${numbers[0]}
    TUIC_PORT=${numbers[1]}
    REALITY_PORT=${numbers[2]}
    ANYTLS_PORT=${numbers[3]}
}

function generate_esb_config() {
    get_ip_info
    generate_reality_keys
    generate_reality_sid
    generate_password
    generate_port

    cat <<EOF > "$CONFIG_FILE"
{
  "server_ip": "$SERVER_IP",
  "vps_org": "$VPS_ORG",
  "country": "$COUNTRY",
  "password": "$PASSWORD",
  "h2_obfs_password": "$H2_OBFS_PASSWORD",
  "h2_port": $H2_PORT,
  "tuic_port": $TUIC_PORT,
  "reality_port": $REALITY_PORT,
  "reality_sid": "$REALITY_SID",
  "public_key": "$PUBLIC_KEY",
  "private_key": "$PRIVATE_KEY",
  "anytls_port": $ANYTLS_PORT
}
EOF
}

function load_esb_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        SERVER_IP=$(jq -r .server_ip "$CONFIG_FILE")
        VPS_ORG=$(jq -r .vps_org "$CONFIG_FILE")
        COUNTRY=$(jq -r .country "$CONFIG_FILE")
        PASSWORD=$(jq -r .password "$CONFIG_FILE")
        H2_OBFS_PASSWORD=$(jq -r .h2_obfs_password "$CONFIG_FILE")
        H2_PORT=$(jq -r .h2_port "$CONFIG_FILE")
        TUIC_PORT=$(jq -r .tuic_port "$CONFIG_FILE")
        REALITY_PORT=$(jq -r .reality_port "$CONFIG_FILE")
        REALITY_SID=$(jq -r .reality_sid "$CONFIG_FILE")
        PUBLIC_KEY=$(jq -r .public_key "$CONFIG_FILE")
        PRIVATE_KEY=$(jq -r .private_key "$CONFIG_FILE")
        ANYTLS_PORT=$(jq -r .anytls_port "$CONFIG_FILE")
    else
        generate_esb_config
        load_esb_config
    fi
}

function generate_singbox_server() {
    load_esb_config

    [[ ! -d "/var/www/html" ]] && mkdir -p "/var/www/html"
    rm -rf $SING_BOX_CONFIG_DIR
    mkdir -p "$SING_BOX_CONFIG_DIR"

    wget --inet4-only -O "$SING_BOX_CONFIG_DIR/cert.pem" https://codeberg.org/easy-sing-box/client/raw/main/cert/cert.pem
    wget --inet4-only -O "$SING_BOX_CONFIG_DIR/private.key" https://codeberg.org/easy-sing-box/client/raw/main/cert/private.key

    cat <<EOF > "$SING_BOX_CONFIG_DIR/config.json"
{
  "log": {
    "level": "error",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "type": "local",
        "tag": "dns"
      }
    ],
    "independent_cache": true
  },
  "inbounds": [
    {
      "type": "tuic",
      "tag": "tuic5",
      "listen": "::",
      "listen_port": $TUIC_PORT,
      "sniff": true,
      "sniff_override_destination": true,
      "users": [
        {
          "uuid": "$PASSWORD",
          "password": "$PASSWORD"
        }
      ],
      "congestion_control": "bbr",
      "tls": {
        "enabled": true,
        "alpn": "h3",
        "certificate_path": "/etc/sing-box/cert.pem",
        "key_path": "/etc/sing-box/private.key"
      }
    },
    {
      "type": "anytls",
      "tag": "anytls",
      "listen": "::",
      "listen_port": $ANYTLS_PORT,
      "sniff": true,
      "sniff_override_destination": true,
      "users": [
        {
          "name": "$PASSWORD",
          "password": "$PASSWORD"
        }
      ],
      "tls": {
        "enabled": true,
        "alpn": "h3",
        "certificate_path": "/etc/sing-box/cert.pem",
        "key_path": "/etc/sing-box/private.key"
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
    "rules": [
      {
        "action": "sniff"
      },
      {
        "protocol": "dns",
        "action": "hijack-dns"
      },
      {
        "protocol": [
          "stun"
        ],
        "outbound": "direct"
      }
    ],
    "final": "direct",
    "default_domain_resolver": "dns"
  }
}
EOF

    systemctl restart sing-box-beta
}

if [[ ! -f "$CONFIG_FILE" ]]; then
    generate_esb_config
fi

load_esb_config
generate_singbox_server

echo "重启 sing-box..."
systemctl restart sing-box-beta
systemctl enable sing-box

clear
echo -e "\e[1;33mSuccess!\033[0m"

RESPONSE_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$CENTRAL_API/api/hello" -H "Content-Type: application/json" --data @$CONFIG_FILE)
if [[ "$RESPONSE_CODE" == "200" ]]; then
    echo "推送到 Central API 成功 ($CENTRAL_API)"
fi