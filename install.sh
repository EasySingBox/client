sudo apt-get install -y nginx python3 python3-pip python3-venv
bash <(curl -Ls https://github.com/team-cloudchaser/tempest/raw/main/install/singbox.sh)
bash <(curl -Ls https://github.com/team-cloudchaser/tempest/raw/main/install/xray.sh)
rm -rf /opt/venv/
cd /opt && mkdir venv
cd /opt/venv && python3 -m venv easy-sing-box
rm -rf /opt/easy-sing-box/
cd /opt && git clone https://github.com/zmlu/easy-sing-box.git
cd /opt/easy-sing-box
source /opt/venv/easy-sing-box/bin/activate
pip3 install -r requirements.txt
python3 generate_config.py
sudo systemctl restart sing-box