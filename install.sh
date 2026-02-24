#!/bin/bash

# 检查是否为root下运行
[[ $EUID -ne 0 ]] && echo -e '\033[1;35m请在root用户下运行脚本\033[0m' && exit 1

echo "开始生成配置..."
bash <(curl -fsSL http://git.io/warp.sh) dwg

CONFIG_FILE="$HOME/esb.config"
SING_BOX_CONFIG_DIR="/etc/sing-box"

if [ $# -lt 2 ] || [ $# -gt 2 ]; then
    echo "用法: $0 <CLOUDFLARE_API_TOKEN> <DOMAIN_NAME>"
    echo ""
    echo "参数说明:"
    echo "  CLOUDFLARE_API_TOKEN: Cloudflare API Token (需要 Zone:Read 和 DNS:Read 权限)"
    echo "  DOMAIN_NAME: 完整域名，例如 app.example.com"
    exit 1
fi

CLOUDFLARE_API_TOKEN="$1"
DOMAIN_NAME="$2"

MIN=10000
MAX=65535

apt install -y git jq gcc wget unzip curl socat cron nginx
mkdir /etc/apt/keyrings/ > /dev/null

sudo apt remove -y sing-box

# install sing-box-beta
curl -fsSL https://sing-box.app/install.sh | sh -s -- --beta

# 安装 acme.sh
curl https://get.acme.sh | sh
ln -sf /root/.acme.sh/acme.sh /usr/local/bin/acme.sh


function get_ip_info() {
    IP_INFO=$(curl -4 https://ip.cloudflare.nyc.mn)
    SERVER_IP=$(echo "$IP_INFO" | jq -r .ip)
    COUNTRY=$(echo "$IP_INFO" | jq -r .country)
    ISP=$(echo "$IP_INFO" | jq -r .isp)
    ASN=$(echo "$IP_INFO" | jq -r .asn)
    VPS_ISP=$(echo "$ISP" | sed "s/$ASN//" | xargs)
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
    NAIVE_PORT=${numbers[4]}
}

function check_and_setup_dns() {
    echo ""
    echo "=========================================="
    echo "[DNS 检查] 验证域名 $DOMAIN_NAME 的 DNS 记录..."
    echo "=========================================="

    API_BASE="https://api.cloudflare.com/client/v4"
    WGET_ARGS=(--no-check-certificate -qO- --header "Authorization: Bearer $CLOUDFLARE_API_TOKEN" --header "Content-Type: application/json")

    # 提取根域名
    DOT_COUNT=$(echo "$DOMAIN_NAME" | grep -o "\." | wc -l)
    if [ "$DOT_COUNT" -ge 2 ]; then
        ROOT_DOMAIN=$(echo "$DOMAIN_NAME" | cut -d'.' -f2-)
    else
        ROOT_DOMAIN="$DOMAIN_NAME"
    fi

    # 获取 Zone ID
    ZONE_RESPONSE=$(wget "${WGET_ARGS[@]}" "${API_BASE}/zones?name=${ROOT_DOMAIN}")
    ZONE_ID=$(echo "$ZONE_RESPONSE" | grep -o '"id":"[a-f0-9]\{32\}"' | head -n 1 | cut -d'"' -f4)

    if [ -z "$ZONE_ID" ]; then
        echo "✗ 无法获取 Zone ID，请检查域名 $ROOT_DOMAIN 是否正确或 Token 权限 (Zone:Read)。"
        exit 1
    fi

    echo "✓ Zone ID: $ZONE_ID"

    # 检查并处理 A 记录 (IPv4)
    ensure_dns_record "A" "$SERVER_IP"

    # 检查并处理 AAAA 记录 (IPv6)
    SERVER_IPV6=$(curl -6 -s --max-time 5 https://ip.cloudflare.nyc.mn | jq -r .ip 2>/dev/null)
    if [ -n "$SERVER_IPV6" ] && [ "$SERVER_IPV6" != "null" ]; then
        echo "✓ 检测到本机 IPv6 地址: $SERVER_IPV6"
        ensure_dns_record "AAAA" "$SERVER_IPV6"
    else
        echo "- 本机不支持 IPv6，跳过 AAAA 记录检查。"
    fi

    echo ""
}

# 确保 DNS 记录存在且指向正确的 IP
# 用法: ensure_dns_record <记录类型 A|AAAA> <目标IP>
function ensure_dns_record() {
    local RECORD_TYPE="$1"
    local TARGET_IP="$2"

    DNS_LIST=$(wget "${WGET_ARGS[@]}" "${API_BASE}/zones/${ZONE_ID}/dns_records?type=${RECORD_TYPE}&name=${DOMAIN_NAME}")
    DNS_CONTENT=$(echo "$DNS_LIST" | grep -o '"content":"[^"]*"' | head -n 1 | cut -d'"' -f4)
    EXISTING_DNS_ID=$(echo "$DNS_LIST" | grep -o '"id":"[a-f0-9]\{32\}"' | head -n 1 | cut -d'"' -f4)

    if [ -z "$DNS_CONTENT" ]; then
        echo "- 未找到 $RECORD_TYPE 记录，正在创建 $DOMAIN_NAME -> $TARGET_IP ..."
        DNS_PAYLOAD="{\"name\":\"${DOMAIN_NAME}\",\"type\":\"${RECORD_TYPE}\",\"content\":\"${TARGET_IP}\",\"proxied\":false}"
        DNS_RESPONSE=$(wget "${WGET_ARGS[@]}" --method=POST --body-data="$DNS_PAYLOAD" "${API_BASE}/zones/${ZONE_ID}/dns_records")
        DNS_SUCCESS=$(echo "$DNS_RESPONSE" | grep -o '"success":[a-z]*' | head -n 1 | cut -d':' -f2)

        if [ "$DNS_SUCCESS" != "true" ]; then
            echo "✗ 创建 $RECORD_TYPE 记录失败: $DNS_RESPONSE"
            exit 1
        fi
        echo "✓ $RECORD_TYPE 记录创建成功: $DOMAIN_NAME -> $TARGET_IP"

    elif [ "$DNS_CONTENT" != "$TARGET_IP" ]; then
        echo "- $RECORD_TYPE 记录指向 $DNS_CONTENT，正在更新为 $TARGET_IP ..."
        DNS_PAYLOAD="{\"name\":\"${DOMAIN_NAME}\",\"type\":\"${RECORD_TYPE}\",\"content\":\"${TARGET_IP}\",\"proxied\":false}"
        DNS_RESPONSE=$(wget "${WGET_ARGS[@]}" --method=PATCH --body-data="$DNS_PAYLOAD" "${API_BASE}/zones/${ZONE_ID}/dns_records/${EXISTING_DNS_ID}")
        DNS_SUCCESS=$(echo "$DNS_RESPONSE" | grep -o '"success":[a-z]*' | head -n 1 | cut -d':' -f2)

        if [ "$DNS_SUCCESS" != "true" ]; then
            echo "✗ 更新 $RECORD_TYPE 记录失败: $DNS_RESPONSE"
            exit 1
        fi
        echo "✓ $RECORD_TYPE 记录更新成功: $DOMAIN_NAME -> $TARGET_IP"

    else
        echo "✓ $RECORD_TYPE 记录验证通过: $DOMAIN_NAME -> $TARGET_IP"
    fi
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
  "domain_name": "$DOMAIN_NAME",
  "country": "$COUNTRY",
  "isp": "$VPS_ISP",
  "password": "$PASSWORD",
  "ss_password": "$SS_PASSWORD",
  "ss_port": $SS_PORT,
  "h2_obfs_password": "$H2_OBFS_PASSWORD",
  "h2_port": $H2_PORT,
  "tuic_port": $TUIC_PORT,
  "naive_port": $NAIVE_PORT,
  "reality_port": $REALITY_PORT,
  "reality_sid": "$REALITY_SID",
  "public_key": "$PUBLIC_KEY",
  "private_key": "$PRIVATE_KEY"
}
EOF
}

function load_esb_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        SERVER_IP=$(jq -r .server_ip "$CONFIG_FILE")
        DOMAIN_NAME=$(jq -r .domain_name "$CONFIG_FILE")
        PASSWORD=$(jq -r .password "$CONFIG_FILE")
        SS_PASSWORD=$(jq -r .ss_password "$CONFIG_FILE")
        SS_PORT=$(jq -r .ss_port "$CONFIG_FILE")
        H2_OBFS_PASSWORD=$(jq -r .h2_obfs_password "$CONFIG_FILE")
        H2_PORT=$(jq -r .h2_port "$CONFIG_FILE")
        TUIC_PORT=$(jq -r .tuic_port "$CONFIG_FILE")
        NAIVE_PORT=$(jq -r .naive_port "$CONFIG_FILE")
        REALITY_PORT=$(jq -r .reality_port "$CONFIG_FILE")
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

    # 重建 sing-box 配置目录
    rm -rf $SING_BOX_CONFIG_DIR
    mkdir -p "$SING_BOX_CONFIG_DIR"

    # 申请并安装域名证书
    echo "=========================================="
    echo "[证书] 为域名 $DOMAIN_NAME 申请 Let's Encrypt 证书..."
    echo "=========================================="
    acme.sh --set-default-ca --server letsencrypt
    acme.sh --issue -d "$DOMAIN_NAME" --standalone --force || {
        echo "✗ 证书申请失败，请检查域名解析是否已生效以及 80 端口是否开放。"
        exit 1
    }
    acme.sh --install-cert -d "$DOMAIN_NAME" --ecc \
        --key-file       "$SING_BOX_CONFIG_DIR/private.key" \
        --fullchain-file "$SING_BOX_CONFIG_DIR/cert.pem" \
        --reloadcmd      "systemctl restart sing-box"
    echo "✓ 证书已安装至 $SING_BOX_CONFIG_DIR"

    wget --inet4-only -O "$SING_BOX_CONFIG_DIR/netflix.srs" https://github.com/DustinWin/ruleset_geodata/releases/download/sing-box-ruleset/netflix.srs
    wget --inet4-only -O "$SING_BOX_CONFIG_DIR/netflixip.srs" https://github.com/DustinWin/ruleset_geodata/releases/download/sing-box-ruleset/netflixip.srs

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
      "type": "naive",
      "tag": "naive",
      "network": "udp",
      "listen": "::",
      "listen_port": 443,
      "users": [
        {
          "username": "zmlu",
          "password": "$PASSWORD"
        }
      ],
      "quic_congestion_control": "bbr2",
      "tls": {
        "enabled": true,
        "server_name": "$DOMAIN_NAME",
        "certificate_path": "$SING_BOX_CONFIG_DIR/cert.pem",
        "key_path": "$SING_BOX_CONFIG_DIR/private.key"
      },
    },
    {
      "type": "shadowsocks",
      "tag": "ss",
      "listen": "::",
      "listen_port": $SS_PORT,
      "sniff": true,
      "sniff_override_destination": true,
      "method": "2022-blake3-aes-256-gcm",
      "password": "$SS_PASSWORD"
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
      "congestion_control": "cubic",
      "tls": {
        "enabled": true,
        "alpn": "h3",
        "certificate_path": "$SING_BOX_CONFIG_DIR/cert.pem",
        "key_path": "$SING_BOX_CONFIG_DIR/private.key"
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
        "alpn": "h3",
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
    },
    {
      "type": "hysteria2",
      "tag": "hy2",
      "listen": "::",
      "listen_port": $H2_PORT,
      "sniff": true,
      "sniff_override_destination": true,
      "up_mbps": 1024,
      "down_mbps": 1024,
      "users": [
        {
          "name": "zmlu",
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
      "tag": "direct",
      "domain_resolver": {
        "server": "dns",
        "strategy": "prefer_ipv4"
      }
    },
    {
      "type": "direct",
      "tag": "wgcf",
      "routing_mark": 51888,
      "domain_resolver": {
        "server": "dns",
        "strategy": "ipv6_only"
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
      },
      {
        "rule_set": [
          "netflix",
          "netflixip"
        ],
        "outbound": "wgcf"
      }
    ],
    "rule_set": [
      {
        "type": "local",
        "tag": "netflix",
        "format": "binary",
        "path": "$SING_BOX_CONFIG_DIR/netflix.srs"
      },
      {
        "type": "local",
        "tag": "netflixip",
        "format": "binary",
        "path": "$SING_BOX_CONFIG_DIR/netflixip.srs"
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

check_and_setup_dns

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

echo "重启 warp..."
bash <(curl -fsSL http://git.io/warp.sh) x
bash <(curl -fsSL http://git.io/warp.sh) rwg

echo -e "\e[1;33mSuccess!\033[0m"

cat $HOME/esb.config