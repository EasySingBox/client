#!/bin/bash

# 检查是否为root下运行
[[ $EUID -ne 0 ]] && echo -e '\033[1;35m请在root用户下运行脚本\033[0m' && exit 1

# 檢查是否提供了第一個參數
if [ -z "$1" ]; then
    echo "錯誤：第一個參數 CENTRAL_API 必須填寫！"
    echo "使用方式: bash <(curl -Ls https://github.com/zmlu/easy-sing-box/raw/main/tunnel-middle.sh) <CENTRAL_API> [RANDOM_PORT_MIN] [RANDOM_PORT_MAX]"
    exit 1
fi

apt install -y git
apt install -y jq
mkdir /etc/apt/keyrings/ > /dev/null
# sing-box-beta
sudo curl -fsSL https://sing-box.app/gpg.key -o /etc/apt/keyrings/sagernet.asc
sudo chmod a+r /etc/apt/keyrings/sagernet.asc
echo "deb [arch=`dpkg --print-architecture` signed-by=/etc/apt/keyrings/sagernet.asc] https://deb.sagernet.org/ * *" | \
  sudo tee /etc/apt/sources.list.d/sagernet.list > /dev/null
sudo apt update
sudo apt install sing-box-beta

CENTRAL_API=${1:-""}
FINAL_SERVER_IP=${4}
FINAL_SERVER_PORT=${5}
FINAL_SERVER_PWD=${6}
VPS_ORG_M=${7}
COUNTRY_M=${8}

IP_INFO=$(curl -s -4 api.ip.sb/geoip)
SERVER_IP=$(echo "$IP_INFO" | jq -r .ip)
COUNTRY=$(echo "$IP_INFO" | jq -r .country_code)
VPS_ORG=$(echo "$IP_INFO" | jq -r .organization)

echo "CENTRAL_API: $CENTRAL_API"
echo "FINAL_SERVER_IP: $FINAL_SERVER_IP"
echo "FINAL_SERVER_PORT: $FINAL_SERVER_PORT"
echo "FINAL_SERVER_PWD: $FINAL_SERVER_PWD"
echo "FINAL_SERVER_VPS_ORG: $VPS_ORG_M"
echo "FINAL_SERVER_COUNTRY: $COUNTRY_M"

echo "开始生成配置..."

CONFIG_FILE="$HOME/esb.config"
CONFIG_FILE_M="$HOME/esb-m.config"
SING_BOX_CONFIG_DIR="/etc/sing-box"


# 定義範圍
MIN=10000
MAX=60000
numbers=()
while [ ${#numbers[@]} -lt 4 ]; do
    num=$((RANDOM % ($MAX - $MIN + 1) + $MIN))
    if [[ ! " ${numbers[@]} " =~ " $num " ]]; then
        numbers+=($num)
    fi
done
TUIC_PORT=${numbers[0]}
REALITY_PORT=${numbers[1]}
TUIC_PORT_M=${numbers[2]}
REALITY_PORT_M=${numbers[3]}

function generate_esb_config() {
    XRAY_OUT=$(sing-box generate reality-keypair)
    PRIVATE_KEY=$(echo "$XRAY_OUT" | grep "PrivateKey" | awk '{print $2}')
    PUBLIC_KEY=$(echo "$XRAY_OUT" | grep "PublicKey" | awk '{print $2}')
    REALITY_SID=$(sing-box generate rand 4 --hex | tr -d '\n')
    PASSWORD=$(sing-box generate uuid | tr -d '\n')
    # 定義範圍
    MIN=10000
    MAX=60000

    # 用陣列來儲存隨機數
    numbers=()

    # 迴圈生成 4 個不重複的隨機數
    while [ ${#numbers[@]} -lt 2 ]; do
        # 生成範圍內的隨機數
        num=$((RANDOM % ($MAX - $MIN + 1) + $MIN))

        # 檢查是否已存在該數字
        if [[ ! " ${numbers[@]} " =~ " $num " ]]; then
            numbers+=($num)
        fi
    done

    # 將隨機數賦值給變量
    TUIC_PORT=${numbers[0]}
    REALITY_PORT=${numbers[1]}

    cat <<EOF > "$CONFIG_FILE"
{
  "server_ip": "$SERVER_IP",
  "vps_org": "$VPS_ORG",
  "country": "$COUNTRY",
  "password": "$PASSWORD",
  "tuic_port": $TUIC_PORT,
  "reality_port": $REALITY_PORT,
  "reality_sid": "$REALITY_SID",
  "public_key": "$PUBLIC_KEY",
  "private_key": "$PRIVATE_KEY"
}
EOF
}

function generate_esb_m_config() {
    XRAY_OUT_M=$(sing-box generate reality-keypair)
    PRIVATE_KEY_M=$(echo "$XRAY_OUT" | grep "PrivateKey" | awk '{print $2}')
    PUBLIC_KEY_M=$(echo "$XRAY_OUT" | grep "PublicKey" | awk '{print $2}')
    REALITY_SID_M=$(sing-box generate rand 4 --hex | tr -d '\n')
    PASSWORD_M=$(sing-box generate uuid | tr -d '\n')

    cat <<EOF > "$CONFIG_FILE_M"
{
  "server_ip": "$SERVER_IP",
  "vps_org": "$VPS_ORG_M",
  "country": "$COUNTRY_M",
  "password": "$PASSWORD_M",
  "tuic_port": $TUIC_PORT_M,
  "reality_port": $REALITY_PORT_M,
  "reality_sid": "$REALITY_SID_M",
  "public_key": "$PUBLIC_KEY_M",
  "private_key": "$PRIVATE_KEY_M"
}
EOF
}

function load_esb_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        SERVER_IP=$(jq -r .server_ip "$CONFIG_FILE")
        PASSWORD=$(jq -r .password "$CONFIG_FILE")
        TUIC_PORT=$(jq -r .tuic_port "$CONFIG_FILE")
        REALITY_PORT=$(jq -r .reality_port "$CONFIG_FILE")
        REALITY_SID=$(jq -r .reality_sid "$CONFIG_FILE")
        PUBLIC_KEY=$(jq -r .public_key "$CONFIG_FILE")
        PRIVATE_KEY=$(jq -r .private_key "$CONFIG_FILE")
    else
        generate_esb_config
        load_esb_config
    fi
}

function load_esb_m_config() {
    if [[ -f "$CONFIG_FILE_M" ]]; then
        SERVER_IP=$(jq -r .server_ip "$CONFIG_FILE_M")
        PASSWORD_M=$(jq -r .password "$CONFIG_FILE_M")
        TUIC_PORT_M=$(jq -r .tuic_port "$CONFIG_FILE_M")
        REALITY_PORT_M=$(jq -r .reality_port "$CONFIG_FILE_M")
        REALITY_SID_M=$(jq -r .reality_sid "$CONFIG_FILE_M")
        PUBLIC_KEY_M=$(jq -r .public_key "$CONFIG_FILE_M")
        PRIVATE_KEY_M=$(jq -r .private_key "$CONFIG_FILE_M")
    else
        generate_esb_m_config
        load_esb_m_config
    fi
}

function generate_singbox_server() {
    load_esb_config
    load_esb_m_config

    [[ ! -d "/var/www/html" ]] && mkdir -p "/var/www/html"
    rm -rf $SING_BOX_CONFIG_DIR
    mkdir -p "$SING_BOX_CONFIG_DIR"

    wget -O "$SING_BOX_CONFIG_DIR/cert.pem" https://github.com/zmlu/easy-sing-box/raw/main/cert/cert.pem
    wget -O "$SING_BOX_CONFIG_DIR/private.key" https://github.com/zmlu/easy-sing-box/raw/main/cert/private.key

    cat <<EOF > "$SING_BOX_CONFIG_DIR/config.json"
{
  "log": {
    "level": "error",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "type": "https",
        "server": "cloudflare-dns.com",
        "domain_resolver": "dns-resolver",
        "tag": "dns"
      },
      {
        "type": "udp",
        "server": "1.1.1.1",
        "tag": "dns-resolver"
      }
    ],
    "independent_cache": true,
    "strategy": "ipv4_only"
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
      "type": "vless",
      "tag": "vless",
      "listen": "::",
      "listen_port": $REALITY_PORT,
      "sniff": true,
      "sniff_override_destination": true,
      "users": [
        {
          "uuid": "$PASSWORD",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "yahoo.com",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "yahoo.com",
            "server_port": 443
          },
          "private_key": "$PRIVATE_KEY_M",
          "short_id": "$REALITY_SID_M"
        }
      }
    },
    {
      "type": "tuic",
      "tag": "tuic5-m",
      "listen": "::",
      "listen_port": $TUIC_PORT_M,
      "sniff": true,
      "sniff_override_destination": true,
      "users": [
        {
          "uuid": "$PASSWORD_M",
          "password": "$PASSWORD_M"
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
      "type": "vless",
      "tag": "vless-m",
      "listen": "::",
      "listen_port": $REALITY_PORT_M,
      "sniff": true,
      "sniff_override_destination": true,
      "users": [
        {
          "uuid": "$PASSWORD_M",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "yahoo.com",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "yahoo.com",
            "server_port": 443
          },
          "private_key": "$PRIVATE_KEY",
          "short_id": "$REALITY_SID"
        }
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "tuic",
      "tag": "tunnel-final",
      "server": "$FINAL_SERVER_IP",
      "server_port": $FINAL_SERVER_PORT,
      "uuid": "$FINAL_SERVER_PWD",
      "password": "$FINAL_SERVER_PWD",
      "tls": {
        "enabled": true,
        "server_name": "www.bing.com",
        "insecure": true,
        "alpn": [
          "h3"
        ]
      },
      "tcp_fast_open": true,
      "udp_fragment": true,
      "tcp_multi_path": false
    }
  ],
  "route": {
    "rules": [
      {
        "inbound": [
          "tuic5",
          "vless"
        ],
        "outbound": "direct"
      },
      {
        "inbound": [
          "tuic5-m",
          "vless-m"
        ],
        "outbound": "tunnel-final"
      }
    ],
    "final": "direct",
    "default_domain_resolver": "dns"
  }
}
EOF

    systemctl restart sing-box
}

if [[ ! -f "$CONFIG_FILE" ]]; then
    generate_esb_config
fi

if [[ ! -f "$CONFIG_FILE_M" ]]; then
    generate_esb_m_config
fi

load_esb_config
generate_singbox_server

echo "重启 sing-box..."
systemctl restart sing-box
systemctl enable sing-box

echo "重启 nginx..."
systemctl restart nginx
systemctl enable nginx

clear
echo -e "\e[1;33mSuccess!\033[0m"

if [[ -n "$1" ]]; then
    CENTRAL_API="$1"
    RESPONSE_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$CENTRAL_API/api/hello" -H "Content-Type: application/json" --data @$CONFIG_FILE)
    if [[ "$RESPONSE_CODE" == "200" ]]; then
        echo "$CONFIG_FILE 推送到 Central API 成功 ($CENTRAL_API)"
    fi
fi
if [[ -n "$1" ]]; then
    CENTRAL_API="$1"
    RESPONSE_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$CENTRAL_API/api/hello" -H "Content-Type: application/json" --data @$CONFIG_FILE_M)
    if [[ "$RESPONSE_CODE" == "200" ]]; then
        echo "$CONFIG_FILE_M 推送到 Central API 成功 ($CENTRAL_API)"
    fi
fi