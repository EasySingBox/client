sudo curl -fsSL https://sing-box.app/gpg.key -o /etc/apt/keyrings/sagernet.asc
sudo chmod a+r /etc/apt/keyrings/sagernet.asc
echo "deb [arch=`dpkg --print-architecture` signed-by=/etc/apt/keyrings/sagernet.asc] https://deb.sagernet.org/ * *" | \
  sudo tee /etc/apt/sources.list.d/sagernet.list > /dev/null
sudo apt-get update
sudo apt-get install -y sing-box nginx python3 python3-pip python3-venv
cd /opt && mkdir venv
cd /opt/venv && python3 -m venv easy-sing-box
cd /opt && git clone git@github.com:zmlu/easy-sing-box.git
cd /opt/easy-sing-box
source /opt/venv/easy-sing-box/bin/activate
pip3 install -r requirements.txt
python3 generate_config.py
sudo systemctl restart sing-box