#!/bin/bash

# 检查是否为root下运行
[[ $EUID -ne 0 ]] && echo -e '\033[1;35m请在root用户下运行脚本\033[0m' && exit 1

echo "开始生成配置..."

CONFIG_FILE="$HOME/esb.config"
SING_BOX_CONFIG_DIR="/etc/sing-box"

if [ $# -eq 4 ]; then
    CLOUDFLARE_API_TOKEN="$1"
    DOMAIN_NAME="$2"
    ZEROSSL_KEY_ID="$3"
    ZEROSSL_MAC_KEY="$4"
    CERT_DIR="/etc/letsencrypt/live/$DOMAIN_NAME"
    ACME_WEBROOT="/var/www/certbot"
    USE_TLS=true
elif [ $# -eq 0 ]; then
    USE_TLS=false
else
    echo "用法: $0 [CLOUDFLARE_API_TOKEN DOMAIN_NAME ZEROSSL_KEY_ID ZEROSSL_MAC_KEY]"
    echo ""
    echo "不传参数: 仅生成基础代理配置（无证书、无 DNS、无 naive/hysteria2 入口）"
    echo "传入4个参数:"
    echo "  CLOUDFLARE_API_TOKEN: Cloudflare API Token (需要 Zone:Read 和 DNS:Edit 权限)"
    echo "  DOMAIN_NAME:          完整域名，例如 app.example.com"
    echo "  ZEROSSL_KEY_ID:       ZeroSSL EAB Key ID"
    echo "  ZEROSSL_MAC_KEY:      ZeroSSL EAB MAC Key"
    exit 1
fi

apt install -y git jq gcc wget unzip curl socat cron certbot nginx dnsutils
mkdir /etc/apt/keyrings/ > /dev/null

sudo apt remove -y sing-box

# install sing-box-beta
curl -fsSL https://sing-box.app/install.sh | sh -s -- --beta


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

    SS_PASSWORD=$(sing-box generate rand --base64 32 | tr -d '\n')
    PASSWORD=$(sing-box generate uuid | tr -d '\n')

    XRAY_OUT=$(sing-box generate reality-keypair)
    PRIVATE_KEY=$(echo "$XRAY_OUT" | grep "PrivateKey" | awk '{print $2}')
    PUBLIC_KEY=$(echo "$XRAY_OUT" | grep "PublicKey" | awk '{print $2}')
    REALITY_SID=$(sing-box generate rand 4 --hex | tr -d '\n')

    numbers=()
    while [ ${#numbers[@]} -lt 3 ]; do
        num=$((RANDOM % (65535 - 12345 + 1) + 12345))
        if [[ ! " ${numbers[@]} " =~ " $num " ]]; then
            numbers+=($num)
        fi
    done
    H2_PORT=${numbers[0]}
    SS_PORT=${numbers[1]}
    REALITY_PORT=${numbers[2]}

    wget --inet4-only -O "$SING_BOX_CONFIG_DIR/self_cert.pem" https://raw.githubusercontent.com/EasySingBox/client/refs/heads/main/cert/cert.pem
    wget --inet4-only -O "$SING_BOX_CONFIG_DIR/self_private.key" https://raw.githubusercontent.com/EasySingBox/client/refs/heads/main/cert/private.key

    if [ "$USE_TLS" = true ]; then
        # 生成 ECH 密钥对
        ECH_OUTPUT=$(sing-box generate ech-keypair "$DOMAIN_NAME")
        ECH_CONFIGS=$(echo "$ECH_OUTPUT" | awk '/-----BEGIN ECH CONFIGS-----/,/-----END ECH CONFIGS-----/' | grep -v '^[[:space:]]*$' | sed 's/^[[:space:]]*//' | jq -R . | jq -sc '.')
        ECH_KEYS=$(echo "$ECH_OUTPUT" | awk '/-----BEGIN ECH KEYS-----/,/-----END ECH KEYS-----/' | grep -v '^[[:space:]]*$' | sed 's/^[[:space:]]*//' | jq -R . | jq -sc '.')

        cat <<EOF > "$CONFIG_FILE"
{
  "server_ip": "$SERVER_IP",
  "domain_name": "$DOMAIN_NAME",
  "country": "$COUNTRY",
  "isp": "$VPS_ISP",
  "password": "$PASSWORD",
  "ss_password": "$SS_PASSWORD",
  "ss_port": $SS_PORT,
  "h2_port": $H2_PORT,
  "reality_port": $REALITY_PORT,
  "reality_sid": "$REALITY_SID",
  "public_key": "$PUBLIC_KEY",
  "private_key": "$PRIVATE_KEY",
  "ech_configs": $ECH_CONFIGS,
  "ech_keys": $ECH_KEYS
}
EOF
    else
        cat <<EOF > "$CONFIG_FILE"
{
  "server_ip": "$SERVER_IP",
  "country": "$COUNTRY",
  "isp": "$VPS_ISP",
  "password": "$PASSWORD",
  "ss_password": "$SS_PASSWORD",
  "ss_port": $SS_PORT,
  "h2_port": $H2_PORT,
  "reality_port": $REALITY_PORT,
  "reality_sid": "$REALITY_SID",
  "public_key": "$PUBLIC_KEY",
  "private_key": "$PRIVATE_KEY"
}
EOF
    fi
}

function load_esb_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        SERVER_IP=$(jq -r .server_ip "$CONFIG_FILE")
        PASSWORD=$(jq -r .password "$CONFIG_FILE")
        SS_PASSWORD=$(jq -r .ss_password "$CONFIG_FILE")
        SS_PORT=$(jq -r .ss_port "$CONFIG_FILE")
        H2_PORT=$(jq -r .h2_port "$CONFIG_FILE")
        REALITY_PORT=$(jq -r .reality_port "$CONFIG_FILE")
        REALITY_SID=$(jq -r .reality_sid "$CONFIG_FILE")
        PUBLIC_KEY=$(jq -r .public_key "$CONFIG_FILE")
        PRIVATE_KEY=$(jq -r .private_key "$CONFIG_FILE")
        if [ "$USE_TLS" = true ]; then
            ECH_CONFIGS=$(jq -c '.ech_configs // []' "$CONFIG_FILE")
            ECH_KEYS=$(jq -c '.ech_keys // []' "$CONFIG_FILE")
        fi
    else
        generate_esb_config
        load_esb_config
    fi
}

function setup_nginx_for_acme() {
    echo ""
    echo "=========================================="
    echo "[Nginx] 配置 HTTP-01 ACME 验证服务..."
    echo "=========================================="

    mkdir -p "$ACME_WEBROOT/.well-known/acme-challenge"

    cat > "/etc/nginx/sites-available/acme" <<NGINXEOF
server {
    listen 80;
    server_name $DOMAIN_NAME;
    root $ACME_WEBROOT;
    location /.well-known/acme-challenge/ {
        root $ACME_WEBROOT;
    }
}
NGINXEOF

    ln -sf /etc/nginx/sites-available/acme /etc/nginx/sites-enabled/acme
    rm -f /etc/nginx/sites-enabled/default
    systemctl enable nginx
    systemctl restart nginx
    echo "✓ Nginx 已启动，监听 80 端口"
}

function wait_for_dns_propagation() {
    echo ""
    echo "=========================================="
    echo "[DNS] 等待 $DOMAIN_NAME A 记录传播..."
    echo "=========================================="

    local MAX_WAIT=300
    local INTERVAL=10
    local ELAPSED=0

    while [ $ELAPSED -lt $MAX_WAIT ]; do
        RESOLVED_IP=$(dig +short A "$DOMAIN_NAME" @8.8.8.8 2>/dev/null | tail -n1)
        if [ "$RESOLVED_IP" = "$SERVER_IP" ]; then
            echo "✓ DNS 传播完成: $DOMAIN_NAME -> $SERVER_IP"
            return 0
        fi
        echo "- 当前解析: ${RESOLVED_IP:-未解析}，${ELAPSED}/${MAX_WAIT}s，等待 ${INTERVAL}s..."
        sleep $INTERVAL
        ELAPSED=$((ELAPSED + INTERVAL))
    done

    echo "✗ DNS 传播超时 (${MAX_WAIT}s)，最后解析结果: ${RESOLVED_IP:-空}"
    exit 1
}

function obtain_certificate() {
    echo ""
    echo "=========================================="
    echo "[证书] 检查 $DOMAIN_NAME 的 TLS 证书..."
    echo "=========================================="

    # 续期后自动重启 sing-box 的 deploy hook（每次都确保存在）
    DEPLOY_HOOK="/etc/letsencrypt/renewal-hooks/deploy/restart-sing-box.sh"
    cat > "$DEPLOY_HOOK" <<'HOOKEOF'
#!/bin/bash
systemctl restart sing-box
HOOKEOF
    chmod +x "$DEPLOY_HOOK"

    # 本地证书存在且 30 天内不过期则跳过申请
    if [ -f "$CERT_DIR/fullchain.pem" ]; then
        EXPIRY=$(openssl x509 -enddate -noout -in "$CERT_DIR/fullchain.pem" | cut -d= -f2)
        EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s 2>/dev/null || date -jf "%b %d %T %Y %Z" "$EXPIRY" +%s)
        NOW_EPOCH=$(date +%s)
        DAYS_LEFT=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))
        if [ "$DAYS_LEFT" -gt 30 ]; then
            echo "✓ 本地证书有效，剩余 $DAYS_LEFT 天，跳过申请。"
            return
        fi
        echo "- 证书将在 $DAYS_LEFT 天后过期，重新申请..."
    fi

    certbot certonly \
        --webroot \
        --webroot-path "$ACME_WEBROOT" \
        --server https://acme.zerossl.com/v2/DV90 \
        --eab-kid "$ZEROSSL_KEY_ID" \
        --eab-hmac-key "$ZEROSSL_MAC_KEY" \
        -d "$DOMAIN_NAME" \
        --non-interactive \
        --agree-tos \
        --email hello@banmiya.org

    if [ ! -f "$CERT_DIR/fullchain.pem" ]; then
        echo "✗ 证书申请失败，请检查日志。"
        exit 1
    fi
    echo "✓ 证书申请成功: $CERT_DIR"
}

function generate_singbox_server() {
    load_esb_config

    # 重建 sing-box 配置目录
    rm -rf $SING_BOX_CONFIG_DIR
    mkdir -p "$SING_BOX_CONFIG_DIR"
    HY2_BLOCK=$(cat <<HY2BLOCK
    {
      "type": "hysteria2",
      "tag": "hy2-in",
      "listen": "::",
      "listen_port": $H2_PORT,
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
        "certificate_path": "$SING_BOX_CONFIG_DIR/self_cert.pem",
        "key_path": "$SING_BOX_CONFIG_DIR/self_private.key"
      },
      "masquerade": {
        "type": "string",
        "status_code": 500,
        "content": "The server was unable to complete your request. Please try again later. If this problem persists, please contact support. Server logs contain details of this error with request ID: 839-234."
      },
      "sniff": true,
      "sniff_override_destination": true,
      "tcp_fast_open": true,
      "tcp_multi_path": true
    },
HY2BLOCK
)
    # 构建 TLS 相关入口（需要证书）
    if [ "$USE_TLS" = true ]; then
        NAIVE_BLOCK=$(cat <<NAIVEBLOCK
    ,{
      "type": "naive",
      "tag": "naive-in",
      "listen": "::",
      "listen_port": 443,
      "quic_congestion_control": "bbr2",
      "users": [
        {
          "username": "user-zmlu",
          "password": "$PASSWORD"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$DOMAIN_NAME",
        "certificate_path": "$CERT_DIR/fullchain.pem",
        "key_path": "$CERT_DIR/privkey.pem",
        "ech": {
          "enabled": false,
          "key": $ECH_KEYS
        }
      },
      "sniff": true,
      "sniff_override_destination": true,
      "tcp_fast_open": true,
      "tcp_multi_path": true
    }
NAIVEBLOCK
)
    else
        NAIVE_BLOCK=""
    fi

    cat <<EOF > "$SING_BOX_CONFIG_DIR/config.json"
{
  "log": {
    "disabled": true,
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
${HY2_BLOCK}    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",
      "listen_port": $REALITY_PORT,
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
      },
      "sniff": true,
      "sniff_override_destination": true,
      "tcp_fast_open": true,
      "tcp_multi_path": true
    },
    {
      "type": "shadowsocks",
      "tag": "ss-in",
      "listen": "::",
      "listen_port": $SS_PORT,
      "method": "2022-blake3-aes-256-gcm",
      "password": "$SS_PASSWORD",
      "sniff": true,
      "sniff_override_destination": true,
      "tcp_fast_open": true,
      "tcp_multi_path": true
    }${NAIVE_BLOCK}
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

if [ "$USE_TLS" = true ]; then
    check_and_setup_dns
    setup_nginx_for_acme
    wait_for_dns_propagation
    obtain_certificate
fi

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

cat $SING_BOX_CONFIG_DIR/config.json
cat $HOME/esb.config
