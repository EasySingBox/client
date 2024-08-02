sudo apt-get install -y nginx python3 python3-pip python3-venv
bash <(curl -fsSL https://github.com/team-cloudchaser/tempest/raw/main/install/singbox.sh)
bash <(curl -fsSL https://github.com/team-cloudchaser/tempest/raw/main/install/xray.sh)
rm -rf /opt/venv/
cd /opt && mkdir venv
cd /opt/venv && python3 -m venv easy-sing-box
rm -rf /opt/easy-sing-box/
cd /opt && git clone https://github.com/zmlu/easy-sing-box.git
cd /opt/easy-sing-box || exit
source /opt/venv/easy-sing-box/bin/activate
pip3 install -r requirements.txt
rm -rf /var/www/html/
rm -rf /etc/sing-box/
python3 generate_config.py
cp /opt/easy-sing-box/cert/cert.pem /etc/sing-box/cert.pem
cp /opt/easy-sing-box/cert/private.key /etc/sing-box/private.key
sysctl -w net.core.rmem_max=16777216
sysctl -w net.core.wmem_max=16777216
sudo systemctl enable sing-box
sudo systemctl restart sing-box
bash <(curl -fsSL https://github.com/zmlu/easy-sing-box/raw/main/bbr.sh)