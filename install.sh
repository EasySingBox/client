nginx="/usr/sbin/nginx"
if [ -e "$nginx" ]; then
    echo "nginx 已存在，跳过安装..."
else
    echo "安装 nginx..."
    sudo apt-get install -y nginx
fi

python3="/usr/bin/python3"
if [ -e "$python3" ]; then
    echo "python 已存在，跳过安装..."
else
    echo "安装 python3 python3-pip python3-venv..."
    sudo apt-get install -y python3 python3-pip python3-venv
fi

singbox="/usr/bin/sing-box"
if [ -e "$singbox" ]; then
    echo "sing-box 已存在，跳过安装..."
else
    echo "安装 sing-box..."
    bash <(curl -Ls https://github.com/team-cloudchaser/tempest/raw/main/install/singbox.sh)
fi

xray="/usr/bin/xray"
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
cd /opt && git clone https://github.com/zmlu/easy-sing-box.git
cd /opt/easy-sing-box || exit
source /opt/venv/easy-sing-box/bin/activate
pip3 install -r requirements.txt
rm -rf /var/www/html/
rm -rf /etc/sing-box/
sysctl -w net.core.rmem_max=16777216
sysctl -w net.core.wmem_max=16777216
clear
python3 generate_config.py
cp /opt/easy-sing-box/cert/cert.pem /etc/sing-box/cert.pem
cp /opt/easy-sing-box/cert/private.key /etc/sing-box/private.key
systemctl enable sing-box
systemctl restart sing-box
systemctl restart nginx