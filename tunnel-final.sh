#!/bin/bash

# 检查是否为root下运行
[[ $EUID -ne 0 ]] && echo -e '\033[1;35m请在root用户下运行脚本\033[0m' && exit 1

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
echo "开始生成配置..."

CONFIG_FILE="$HOME/esb.config"
SING_BOX_CONFIG_DIR="/etc/sing-box"
SERVER_PORT=${1:-31315}
echo "SERVER_PORT: $SERVER_PORT"
function generate_esb_config() {
    IP_INFO=$(curl -s -4 ip.network/more)
    SERVER_IP=$(echo "$IP_INFO" | jq -r .ip)
    COUNTRY=$(echo "$IP_INFO" | jq -r .country)
    VPS_ORG=$(echo "$IP_INFO" | jq -r .asOrganization)
    PASSWORD=$(sing-box generate uuid | tr -d '\n')

    cat <<EOF > "$CONFIG_FILE"
{
  "server_ip": "$SERVER_IP",
  "vps_org": "$VPS_ORG",
  "country": "$COUNTRY",
  "password": "$PASSWORD",
  "server_port": $SERVER_PORT
}
EOF
}

function load_esb_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        SERVER_IP=$(jq -r .server_ip "$CONFIG_FILE")
        VPS_ORG=$(jq -r .vps_org "$CONFIG_FILE")
        COUNTRY=$(jq -r .country "$CONFIG_FILE")
        PASSWORD=$(jq -r .password "$CONFIG_FILE")
        SERVER_PORT=$(jq -r .server_port "$CONFIG_FILE")
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
      "listen_port": $SERVER_PORT,
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
        "certificate_path": "$SING_BOX_CONFIG_DIR/cert.pem",
        "key_path": "$SING_BOX_CONFIG_DIR/private.key"
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

load_esb_config
generate_singbox_server

echo "重启 sing-box..."
systemctl restart sing-box
systemctl enable sing-box

clear
echo -e "\e[1;33mSuccess!\033[0m"