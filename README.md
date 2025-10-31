## easy-sing-box

## Install & update

### Install

```shell
bash <(curl -Ls https://raw.githubusercontent.com/EasySingBox/client/refs/heads/main/install.sh?_=$(date +%s)) <CENTRAL_API> [RANDOM_PORT_MIN] [RANDOM_PORT_MAX]
```

### Update

```shell
bash <(curl -Ls https://raw.githubusercontent.com/EasySingBox/client/refs/heads/main/update.sh?_=$(date +%s)) <CENTRAL_API> [RANDOM_PORT_MIN] [RANDOM_PORT_MAX]
```

## XanMod Core installation

```shell
sudo apt update && sudo apt upgrade

# add APT
sudo apt install -y gnupg
echo 'deb http://deb.xanmod.org releases main' | sudo tee /etc/apt/sources.list.d/xanmod-kernel.list
wget --no-check-certificate -qO - https://gitlab.com/afrd.gpg | sudo apt-key --keyring /etc/apt/trusted.gpg.d/xanmod-kernel.gpg add -

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
sudo apt remove linux-image-virtual

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

## Check tcp-brutal startup successfully

```shell
dkms status
```
output:
```text
tcp-brutal/1.0.3, 6.13.8-x64v3-xanmod1, x86_64: installed
```
If failed, check [https://github.com/apernet/tcp-brutal/issues/7](https://github.com/apernet/tcp-brutal/issues/7)

```shell
cat /var/lib/dkms/tcp-brutal/1.0.0/build/make.log
```

### `clang: not found`

```bash
sudo apt install clang
```

### `lld: not found`

```bash
sudo apt install lld
```