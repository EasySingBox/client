#!/bin/bash

# 检查是否为root下运行
[[ $EUID -ne 0 ]] && echo -e '\033[1;35m请在root用户下运行脚本\033[0m' && exit 1

echo "开始生成配置..."

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

apt install -y git jq gcc wget unzip curl socat cron nginx
mkdir /etc/apt/keyrings/ > /dev/null

sudo apt remove -y sing-box

# install sing-box-beta
curl -fsSL https://sing-box.app/install.sh | sh -s -- --beta

# 安装 acme.sh
curl https://get.acme.sh | sh
ln -sf /root/.acme.sh/acme.sh /usr/local/bin/acme.sh

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
  "domain_name": "$DOMAIN_NAME",
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

# 重建 sing-box 配置目录
    rm -rf $SING_BOX_CONFIG_DIR
    mkdir -p "$SING_BOX_CONFIG_DIR"

    # 申请并安装域名证书
    echo "=========================================="
    echo "[证书] 为域名 $DOMAIN_NAME 申请 Let's Encrypt 证书..."
    echo "=========================================="
    systemctl start nginx
    acme.sh --set-default-ca --server letsencrypt
    CERT_DIR="$HOME/.acme.sh/${DOMAIN_NAME}_ecc"
    if [ -f "$CERT_DIR/${DOMAIN_NAME}.cer" ]; then
        echo "✓ 证书已存在，跳过申请直接安装..."
    else
        acme.sh --issue -d "$DOMAIN_NAME" --standalone || {
            echo "✗ 证书申请失败，请检查域名解析是否已生效以及 80 端口是否开放。"
            exit 1
        }
    fi
    acme.sh --install-cert -d "$DOMAIN_NAME" --ecc \
        --key-file       "$SING_BOX_CONFIG_DIR/private.key" \
        --fullchain-file "$SING_BOX_CONFIG_DIR/cert.pem" \
        --reloadcmd      "systemctl restart sing-box"
    echo "✓ 证书已安装至 $SING_BOX_CONFIG_DIR"

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
      "tag": "naive-in",
      "listen": "::",
      "listen_port": 443,
      "sniff": true,
      "sniff_override_destination": true,
      "tcp_fast_open": true,
      "users": [
        {
          "username": "user-zmlu",
          "password": "$PASSWORD"
        }
      ],
      "quic_congestion_control": "bbr2"
      "tls": {
        "enabled": true,
        "server_name": "$DOMAIN_NAME",
        "certificate_path": "$SING_BOX_CONFIG_DIR/cert.pem",
        "key_path": "$SING_BOX_CONFIG_DIR/private.key"
      },
    },
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",
      "listen_port": 443,
      "sniff": true,
      "sniff_override_destination": true,
      "tcp_fast_open": true,
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

echo "配置 nginx 反向代理..."
cat <<'NGINX_EOF' > "/etc/nginx/sites-available/default"
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    location / {
        proxy_pass https://www.apple.com;
        proxy_set_header Host www.apple.com;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_ssl_server_name on;
    }
}
NGINX_EOF
nginx -t && systemctl restart nginx
echo "✓ nginx 反向代理已配置 -> https://www.apple.com"

echo -e "\e[1;33mSuccess!\033[0m"

cat $HOME/esb.config