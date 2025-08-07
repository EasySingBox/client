#!/bin/bash

# 检查是否为root下运行
[[ $EUID -ne 0 ]] && echo -e '\033[1;35m请在root用户下运行脚本\033[0m' && exit 1

echo "开始生成配置..."

CONFIG_FILE="$HOME/esb.config"
SING_BOX_CONFIG_DIR="/etc/sing-box"
SNELL_CONFIG_DIR="/etc/snell"
CENTRAL_API="$1"
MIN=${2:-10000}
MAX=${3:-65535}

if [ -z "$1" ]; then
echo "CENTRAL_API: $CENTRAL_API"
fi
echo "RANDOM_PORT_MIN: $MIN"
echo "RANDOM_PORT_MAX: $MAX"

function get_ip_info() {
    IP_INFO=$(curl -s -4 ip.network/more)
    SERVER_IP=$(echo "$IP_INFO" | jq -r .ip)
    COUNTRY=$(echo "$IP_INFO" | jq -r .country)
    VPS_ORG_FULL=$(echo "$IP_INFO" | jq -r .asOrganization)
    VPS_ORG=$(echo "$VPS_ORG_FULL" | cut -d' ' -f1)
}

function generate_password() {
    SS_PASSWORD=$(sing-box generate rand --base64 32 | tr -d '\n')
    PASSWORD=$(sing-box generate uuid | tr -d '\n')
    SNELL_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 20)
}

function generate_port() {
    numbers=()
    while [ ${#numbers[@]} -lt 3 ]; do
        num=$((RANDOM % ($MAX - $MIN + 1) + $MIN))
        if [[ ! " ${numbers[@]} " =~ " $num " ]]; then
            numbers+=($num)
        fi
    done

    SS_PORT=${numbers[0]}
    ANYTLS_PORT=${numbers[1]}
    SNELL_PORT=${numbers[2]}
}

function generate_esb_config() {
    get_ip_info
    generate_password
    generate_port

    cat <<EOF > "$CONFIG_FILE"
{
  "server_ip": "$SERVER_IP",
  "vps_org": "$VPS_ORG",
  "country": "$COUNTRY",
  "password": "$PASSWORD",
  "ss_password": "$SS_PASSWORD",
  "ss_port": $SS_PORT,
  "anytls_port": $ANYTLS_PORT,
  "snell_port": $SNELL_PORT,
  "snell_password": "$SNELL_PASSWORD"
}
EOF
}

function load_esb_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        SERVER_IP=$(jq -r .server_ip "$CONFIG_FILE")
        VPS_ORG=$(jq -r .vps_org "$CONFIG_FILE")
        COUNTRY=$(jq -r .country "$CONFIG_FILE")
        PASSWORD=$(jq -r .password "$CONFIG_FILE")
        SS_PASSWORD=$(jq -r .ss_password "$CONFIG_FILE")
        SS_PORT=$(jq -r .ss_port "$CONFIG_FILE")
        ANYTLS_PORT=$(jq -r .anytls_port "$CONFIG_FILE")
        SNELL_PORT=$(jq -r .snell_port "$CONFIG_FILE")
        SNELL_PASSWORD=$(jq -r .snell_password "$CONFIG_FILE")
    else
        generate_esb_config
        load_esb_config
    fi
}

function generate_singbox_server() {
    load_esb_config

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
      "type": "shadowsocks",
      "tag": "ss",
      "listen": "::",
      "listen_port": $SS_PORT,
      "tcp_fast_open": true,
      "tcp_multi_path": true,
      "method": "2022-blake3-aes-256-gcm",
      "password": "$SS_PASSWORD",
      "multiplex": {
        "enabled": true,
        "padding": true,
        "brutal": {
          "enabled": true,
          "up_mbps": 500,
          "down_mbps": 500
        }
      }
    },
    {
      "type": "anytls",
      "tag": "anytls",
      "listen": "::",
      "listen_port": $ANYTLS_PORT,
      "users": [
        {
          "name": "$PASSWORD",
          "password": "$PASSWORD"
        }
      ],
      "tls": {
        "enabled": true,
        "alpn": [
          "h2",
          "http/1.1"
        ],
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
}

function generate_snell_server() {
    load_esb_config

    rm -rf $SNELL_CONFIG_DIR
    mkdir -p "$SNELL_CONFIG_DIR"

        # 创建配置文件
    # 创建配置文件
    cat <<EOF > "$SNELL_CONFIG_DIR/users/snell-main.conf"
[snell-server]
listen = ::0:${SNELL_PORT}
psk = ${SNELL_PASSWORD}
ipv6 = true
EOF
}

if [[ ! -f "$CONFIG_FILE" ]]; then
    generate_esb_config
fi

load_esb_config
generate_singbox_server

cat <<EOF > "/usr/lib/systemd/system/sing-box.service"
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target network-online.target

[Service]
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
ExecStart=/usr/bin/sing-box -D /var/lib/sing-box -C /etc/sing-box run
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=10s
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

# 创建 Systemd 服务文件
cat <<EOF > "/lib/systemd/system/snell.service"
[Unit]
Description=Snell Proxy Service
After=network.target

[Service]
Type=simple
User=snell
Group=snell
ExecStart=/usr/local/bin/snell-server -c $SNELL_CONFIG_DIR/users/snell-main.conf
AmbientCapabilities=CAP_NET_BIND_SERVICE CAP_NET_ADMIN CAP_NET_RAW
CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_NET_ADMIN CAP_NET_RAW
LimitNOFILE=32768
Restart=on-failure
StandardOutput=journal
StandardError=journal
SyslogIdentifier=snell-server

[Install]
WantedBy=multi-user.target
EOF

echo "重启 sing-box、snell..."
systemctl daemon-reload
systemctl restart sing-box
systemctl enable sing-box
systemctl enable snell
systemctl restart snell

clear
echo -e "\e[1;33mSuccess!\033[0m"

if [ -z "$1" ]; then
  RESPONSE_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$CENTRAL_API/api/hello" -H "Content-Type: application/json" --data @$CONFIG_FILE)
  if [[ "$RESPONSE_CODE" == "200" ]]; then
      echo "推送到 Central API 成功 ($CENTRAL_API)"
  fi
fi