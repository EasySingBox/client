#!/bin/bash

# 检查是否为root下运行
[[ $EUID -ne 0 ]] && echo -e '\033[1;35m请在root用户下运行脚本\033[0m' && exit 1

echo "开始生成配置..."

CONFIG_FILE="$HOME/esb.config"
SING_BOX_CONFIG_DIR="/etc/sing-box"

apt install -y git jq gcc wget unzip curl
mkdir /etc/apt/keyrings/ > /dev/null

sudo apt remove -y sing-box

# install sing-box-beta
curl -fsSL https://sing-box.app/install.sh | sh -s -- --beta

function generate_esb_config() {
    IP_INFO=$(curl -4 https://ip.cloudflare.nyc.mn)
    SERVER_IP=$(echo "$IP_INFO" | jq -r .ip)
    COUNTRY=$(echo "$IP_INFO" | jq -r .country)
    ISP=$(echo "$IP_INFO" | jq -r .isp)
    ASN=$(echo "$IP_INFO" | jq -r .asn)
    VPS_ISP=$(echo "$ISP" | sed "s/$ASN//" | xargs)
    XRAY_OUT=$(sing-box generate reality-keypair)
    PRIVATE_KEY=$(echo "$XRAY_OUT" | grep "PrivateKey" | awk '{print $2}')
    PUBLIC_KEY=$(echo "$XRAY_OUT" | grep "PublicKey" | awk '{print $2}')
    REALITY_SID=$(sing-box generate rand 4 --hex | tr -d '\n')
    PASSWORD=$(sing-box generate uuid | tr -d '\n')

    cat <<EOF > "$CONFIG_FILE"
{
  "server_ip": "$SERVER_IP",
  "country": "$COUNTRY",
  "isp": "$VPS_ISP",
  "password": "$PASSWORD",
  "reality_sid": "$REALITY_SID",
  "public_key": "$PUBLIC_KEY",
  "private_key": "$PRIVATE_KEY"
}
EOF
}

function load_esb_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        SERVER_IP=$(jq -r .server_ip "$CONFIG_FILE")
        PASSWORD=$(jq -r .password "$CONFIG_FILE")
        REALITY_SID=$(jq -r .reality_sid "$CONFIG_FILE")
        PUBLIC_KEY=$(jq -r .public_key "$CONFIG_FILE")
        PRIVATE_KEY=$(jq -r .private_key "$CONFIG_FILE")
    else
        generate_esb_config
        load_esb_config
    fi
}

function generate_singbox_server() {
    load_esb_config

    rm -rf $SING_BOX_CONFIG_DIR
    mkdir -p "$SING_BOX_CONFIG_DIR"

    wget --inet4-only -O "$SING_BOX_CONFIG_DIR/cert.pem" https://raw.githubusercontent.com/EasySingBox/client/refs/heads/main/cert/cert.pem
    wget --inet4-only -O "$SING_BOX_CONFIG_DIR/private.key" https://raw.githubusercontent.com/EasySingBox/client/refs/heads/main/cert/private.key

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
      "network": "udp",
      "listen_port": 443,
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
      "listen_port": 443,
      "network": "tcp",
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
        "alpn": "h3",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "www.apple.com",
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
      "tag": "direct",
      "domain_resolver": {
        "server": "dns",
        "strategy": "ipv4_only"
      }
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

if [[ ! -f "$CONFIG_FILE" ]]; then
    generate_esb_config
fi

load_esb_config

generate_singbox_server

cat <<EOF > "/usr/lib/systemd/system/sing-box.service"
[Unit]
Description=esb
Documentation=https://esb.banmiya.org
After=network.target nss-lookup.target network-online.target

[Service]
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
ExecStart=/usr/bin/sing-box -D /var/lib/sing-box -C /etc/sing-box run
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=10s
LimitNOFILE=infinity
CPUSchedulingPolicy=rr
CPUSchedulingPriority=99

[Install]
WantedBy=multi-user.target
EOF

echo "重启 sing-box..."
systemctl daemon-reload
systemctl restart sing-box
systemctl enable sing-box

echo -e "\e[1;33mSuccess!\033[0m"

cat $HOME/esb.config