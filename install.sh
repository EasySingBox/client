nginx="/usr/sbin/nginx"
python3="/usr/bin/python3"
singbox="/usr/bin/sing-box"
xray="/usr/bin/xray"
if [ -e "$nginx" ]; then
    echo "nginx 已存在，跳过安装..."
else
    echo "安装 nginx..."
    sudo apt-get install -y nginx
fi
if [ -e "$python3" ]; then
    echo "python 已存在，跳过安装..."
else
    echo "安装 python3 python3-pip python3-venv..."
    sudo apt-get install -y python3 python3-pip python3-venv
fi
if [ -e "$singbox" ]; then
    echo "sing-box 已存在，跳过安装..."
else
    echo "安装 sing-box..."
    bash <(curl -Ls https://github.com/team-cloudchaser/tempest/raw/main/install/singbox.sh)
fi
if [ -e "$xray" ]; then
    echo "xray 已存在，跳过安装..."
else
    echo "安装 xray..."
    bash <(curl -Ls https://github.com/team-cloudchaser/tempest/raw/main/install/xray.sh)
fi
echo "重置 venv..."
rm -rf /opt/venv/
cd /opt && mkdir venv
cd /opt/venv && python3 -m venv easy-sing-box
echo "重置 easy-sing-box..."
rm -rf /opt/easy-sing-box/
cd /opt && git clone -q https://github.com/zmlu/easy-sing-box.git > /dev/null 2>&1
cd /opt/easy-sing-box || exit
echo "安装 easy-sing-box 依赖..."
source /opt/venv/easy-sing-box/bin/activate
pip3 install -r requirements.txt
echo "开始生成配置..."
rm -rf /var/www/html/
rm -rf /etc/sing-box/
sysctl -w net.core.rmem_max=16777216 > /dev/null 2>&1
sysctl -w net.core.wmem_max=16777216 > /dev/null 2>&1
clear
python3 generate_config.py
cp /opt/easy-sing-box/cert/cert.pem /etc/sing-box/cert.pem
cp /opt/easy-sing-box/cert/private.key /etc/sing-box/private.key
echo "重启 sing-box..."
systemctl enable sing-box
systemctl restart sing-box
echo "重启 nginx..."
systemctl restart nginx