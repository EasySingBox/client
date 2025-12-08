#!/bin/bash

# 检查是否为root下运行
[[ $EUID -ne 0 ]] && echo -e '\033[1;35m请在root用户下运行脚本\033[0m' && exit 1

ARGO_DOMAIN=${2:-''}
$ARGO_AUTH=${3:-''}

echo "ARGO_DOMAIN: $ARGO_DOMAIN"
echo "ARGO_AUTH: $ARGO_AUTH"

apt install -y git jq gcc wget unzip curl
mkdir /etc/apt/keyrings/ > /dev/null

sudo apt remove -y sing-box
sudo apt remove -y sing-box-beta

# install sing-box-beta
curl -fsSL https://sing-box.app/install.sh | sh -s -- --beta

# install hy2-tcp
bash <(curl -fsSL https://tcp.hy2.sh/)

IP_INFO=$(curl -4 https://free.freeipapi.com/api/json)
SERVER_IP=$(echo "$IP_INFO" | jq -r .ipAddress)
COUNTRY=$(echo "$IP_INFO" | jq -r .countryCode)
VPS_ORG_FULL=$(echo "$IP_INFO" | jq -r .asnOrganization)
VPS_ORG=$(echo "$VPS_ORG_FULL" | cut -d' ' -f1)
XRAY_OUT=$(sing-box generate reality-keypair)
PRIVATE_KEY=$(echo "$XRAY_OUT" | grep "PrivateKey" | awk '{print $2}')
PUBLIC_KEY=$(echo "$XRAY_OUT" | grep "PublicKey" | awk '{print $2}')
PASSWORD=$(sing-box generate uuid | tr -d '\n')

# gen config
bash <(wget -qO- https://raw.githubusercontent.com/zmlu/sing-box/main/sing-box.sh) \
  --LANGUAGE c \
  --CHOOSE_PROTOCOLS a \
  --START_PORT 10000 \
  --PORT_NGINX 60000 \
  --SERVER_IP $SERVER_IP \
  --CDN skk.moe \
  --UUID_CONFIRM $PASSWORD \
  --SUBSCRIBE=true \
  --ARGO=true \
  --ARGO_DOMAIN=$ARGO_DOMAIN \
  --ARGO_AUTH='sudo cloudflared service install $ARGO_AUTH' \
  --PORT_HOPPING_RANGE 50000:51000 \
  --REALITY_PRIVATE=$PRIVATE_KEY \
  --NODE_NAME_CONFIRM bucket