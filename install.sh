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
sudo apt-get update
sudo apt-get install sing-box-beta
echo "重置 warp..."
bash <(curl -fsSL git.io/warp.sh) x

echo "开始生成配置..."

CONFIG_FILE="$HOME/esb.config"
SING_BOX_CONFIG_DIR="/etc/sing-box"
NGINX_WWW_DIR="/var/www/html"

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
}

function generate_port() {
    H2_PORT=$((RANDOM % 64536 + 9000))
    TUIC_PORT=$((RANDOM % 64536 + 9000))
    REALITY_PORT=$((RANDOM % 64536 + 9000))
    ANYTLS_PORT=$((RANDOM % 64536 + 9000))
}

function generate_esb_config() {
    get_ip_info
    generate_reality_keys
    generate_reality_sid
    generate_password
    generate_port
    WWW_DIR_RANDOM_ID=$(cat /proc/sys/kernel/random/uuid | cut -c 1-6)

    cat <<EOF > "$CONFIG_FILE"
{
  "server_ip": "$SERVER_IP",
  "vps_org": "$VPS_ORG",
  "country": "$COUNTRY",
  "www_dir_random_id": "$WWW_DIR_RANDOM_ID",
  "password": "$PASSWORD",
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
        WWW_DIR_RANDOM_ID=$(jq -r .www_dir_random_id "$CONFIG_FILE")
        PASSWORD=$(jq -r .password "$CONFIG_FILE")
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
    rm -rf $NGINX_WWW_DIR/$WWW_DIR_RANDOM_ID
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
        "server": "$SERVER_IP",
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
      "type": "hysteria2",
      "tag": "hy2",
      "listen": "::",
      "listen_port": $H2_PORT,
      "sniff": true,
      "sniff_override_destination": true,
      "up_mbps": 500,
      "down_mbps": 500,
      "users": [
        {
          "name": "user-jacob",
          "password": "$PASSWORD"
        }
      ],
      "tls": {
        "enabled": true,
        "alpn": "h3",
        "certificate_path": "$SING_BOX_CONFIG_DIR/cert.pem",
        "key_path": "$SING_BOX_CONFIG_DIR/private.key"
      }
    }
  ]
}
EOF

    systemctl restart sing-box
}

function generate_clash_meta() {
    [[ ! -d "$NGINX_WWW_DIR/$WWW_DIR_RANDOM_ID" ]] && mkdir -p "$NGINX_WWW_DIR/$WWW_DIR_RANDOM_ID"
    wget -O "$NGINX_WWW_DIR/$WWW_DIR_RANDOM_ID/geoip.dat" https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
    wget -O "$NGINX_WWW_DIR/$WWW_DIR_RANDOM_ID/geosite.dat" https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat
    wget -O "$NGINX_WWW_DIR/$WWW_DIR_RANDOM_ID/Country.mmdb" https://github.com/Loyalsoldier/geoip/raw/refs/heads/release/Country.mmdb
}

if [[ ! -f "$CONFIG_FILE" ]]; then
    generate_esb_config
fi

load_esb_config
generate_singbox_server
#generate_clash_meta

echo "重启 sing-box..."
systemctl restart sing-box
systemctl enable sing-box

echo "重启 nginx..."
systemctl restart nginx
systemctl enable nginx

clear
echo -e "\e[1;33mClash.Meta\033[0m"
echo -e "\e[1;32mhttp://$SERVER_IP/$WWW_DIR_RANDOM_ID/meta.yaml\033[0m"
