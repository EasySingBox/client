## easy-sing-box

## Install & update

### Normal with wg-quick

#### Install

```shell
bash <(curl -Ls https://codeberg.org/easy-sing-box/client/raw/main/install.sh?_=$(date +%s)) <CENTRAL_API> [RANDOM_PORT_MIN] [RANDOM_PORT_MAX]
```

#### Update

```shell
bash <(curl -Ls https://codeberg.org/easy-sing-box/client/raw/main/update.sh?_=$(date +%s)) <CENTRAL_API> [RANDOM_PORT_MIN] [RANDOM_PORT_MAX]
```

### Normal without wg-quick

#### Install

```shell
#Install
bash <(curl -Ls https://codeberg.org/easy-sing-box/client/raw/main/install-nonf.sh?_=$(date +%s)) <CENTRAL_API> [RANDOM_PORT_MIN] [RANDOM_PORT_MAX]
```

#### Update

```shell
#Update
bash <(curl -Ls https://codeberg.org/easy-sing-box/client/raw/main/update-nonf.sh?_=$(date +%s)) <CENTRAL_API> [RANDOM_PORT_MIN] [RANDOM_PORT_MAX]
```

### Tunnel

#### Middle VPS

```shell
bash <(curl -Ls https://codeberg.org/easy-sing-box/client/raw/main/tunnel-middle.sh?_=$(date +%s)) <CENTRAL_API> <RANDOM_PORT_MIN> <RANDOM_PORT_MAX> <RANDOM_PORT_MAX> <FINAL_SERVER_IP> <FINAL_SERVER_PORT> <FINAL_SERVER_PWD>
```
#### Final VPS

```shell
bash <(curl -Ls https://codeberg.org/easy-sing-box/client/raw/main/tunnel-final.sh?_=$(date +%s)) [SERVER_PORT]
```

## XanMod Core installation

```shell
sudo apt update && sudo apt upgrade

# add APT
sudo apt install -y gnupg
echo 'deb http://deb.xanmod.org releases main' | sudo tee /etc/apt/sources.list.d/xanmod-kernel.list
wget -qO - https://dl.xanmod.org/gpg.key | sudo apt-key --keyring /etc/apt/trusted.gpg.d/xanmod-kernel.gpg add -

sudo apt update

# check cpu versions
awk -f <(wget -O - https://dl.xanmod.org/check_x86-64_psabi.sh)

# install
sudo apt update && sudo apt install linux-xanmod-edge-x64v4

reboot

# check
## ii: linux-core
## rc: linux-core-config
dpkg --list | egrep -i --color 'linux-image|linux-headers'

# remove linux-core
sudo apt remove linux-image-5.10.0-26-amd64

# remove linux-core-config
sudo apt purge linux-image-amd64

sudo apt-get update
sudo apt-get autoremove

# update GRUB
sudo update-grub

# core optimization shell
wget https://raw.githubusercontent.com/honorcnboy/BlogDatas/main/VpsScript/Optimization-v2.sh && chmod +x ./Optimization-v2.sh && sudo bash ./Optimization-v2.sh
```

#### XanMod Core Installation

```shell
cat /proc/version

uname -mrs

modinfo tcp_bbr
```

## Enable bbr

```shell
wget --no-check-certificate -O /opt/bbr.sh https://raw.githubusercontent.com/zmlu/across/master/bbr.sh && chmod 755 /opt/bbr.sh && /opt/bbr.sh
```