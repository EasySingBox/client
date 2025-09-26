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
    VPS_ORG_FULL=$(echo "$IP_INFO" | jq -r .asOrganization)
    VPS_ORG=$(echo "$VPS_ORG_FULL" | cut -d' ' -f1)
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
    SS_PASSWORD=$(sing-box generate rand --base64 32 | tr -d '\n')
    PASSWORD=$(sing-box generate uuid | tr -d '\n')
    H2_OBFS_PASSWORD=$(sing-box generate uuid | tr -d '\n')
}

function generate_port() {
    numbers=()
    while [ ${#numbers[@]} -lt 5 ]; do
        num=$((RANDOM % ($MAX - $MIN + 1) + $MIN))
        if [[ ! " ${numbers[@]} " =~ " $num " ]]; then
            numbers+=($num)
        fi
    done

    H2_PORT=${numbers[0]}
    TUIC_PORT=${numbers[1]}
    SS_PORT=${numbers[2]}
    REALITY_PORT=${numbers[3]}
    ANYTLS_PORT=${numbers[4]}
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
  "ss_password": "$SS_PASSWORD",
  "ss_port": $SS_PORT,
  "h2_obfs_password": "$H2_OBFS_PASSWORD",
  "h2_port": $H2_PORT,
  "tuic_port": $TUIC_PORT,
  "reality_port": $REALITY_PORT,
  "reality_sid": "$REALITY_SID",
  "public_key": "$PUBLIC_KEY",
  "private_key": "$PRIVATE_KEY",
  "anytls_port": $ANYTLS_PORT,
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
      "listen": "127.0.0.1",
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
      },
      "tcp_fast_open": true,
      "tcp_multi_path": true
    },
    {
      "type": "shadowtls",
      "tag": "shadowtls",
      "version": 3,
      "listen": "::",
      "listen_port": $SS_PORT,
      "detour": "ss",
      "users": [
        {
          "name": "$SS_PASSWORD",
          "password": "$SS_PASSWORD"
        }
      ],
      "handshake":{
        "server": "icloud.com",
        "server_port": 443,
        "tcp_fast_open": true,
        "tcp_multi_path": true
      },
      "strict_mode": true,
      "wildcard_sni": "authed",
      "tcp_fast_open": true,
      "tcp_multi_path": true
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
    },
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
        "alpn": [
          "h3"
        ],
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
          "flow": ""
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "yahoo.com",
        "alpn": "h3",
        "certificate_path": "/etc/sing-box/cert.pem",
        "key_path": "/etc/sing-box/private.key"
      }
    },
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
      },
      "masquerade": {
        "type": "string",
        "status_code": 500,
        "content": "The server was unable to complete your request. Please try again later. If this problem persists, please contact support. Server logs contain details of this error with request ID: 839-234."
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

# 开放端口 (ufw 和 iptables)
open_port() {
    local PORT=$1
    # 检查 ufw 是否已安装
    if command -v ufw &> /dev/null; then
        echo -e "${CYAN}在 UFW 中开放端口 $PORT${RESET}"
        ufw allow "$PORT"/tcp
    fi

    # 检查 iptables 是否已安装
    if command -v iptables &> /dev/null; then
        echo -e "${CYAN}在 iptables 中开放端口 $PORT${RESET}"
        iptables -I INPUT -p tcp --dport "$PORT" -j ACCEPT

        # 创建 iptables 规则保存目录（如果不存在）
        if [ ! -d "/etc/iptables" ]; then
            mkdir -p /etc/iptables
        fi

        # 尝试保存规则，如果失败则不中断脚本
        iptables-save > /etc/iptables/rules.v4 || true
    fi
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

echo "重启 sing-box..."
systemctl daemon-reload
systemctl restart sing-box
systemctl enable sing-box


clear
echo -e "\e[1;33mSuccess!\033[0m"

RESPONSE_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$CENTRAL_API/api/hello" -H "Content-Type: application/json" --data @$CONFIG_FILE)
if [[ "$RESPONSE_CODE" == "200" ]]; then
    echo "推送到 Central API 成功 ($CENTRAL_API)"
fi