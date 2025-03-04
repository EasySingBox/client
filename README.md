## easy-sing-box

### 安装 & 更新

```shell
bash <(curl -Ls https://github.com/zmlu/easy-sing-box/raw/main/install.sh?_=$(date +%s)) <CENTRAL_API> [RANDOM_PORT_MIN] [RANDOM_PORT_MAX]

#update
bash <(curl -Ls https://github.com/zmlu/easy-sing-box/raw/main/update.sh?_=$(date +%s)) <CENTRAL_API> [RANDOM_PORT_MIN] [RANDOM_PORT_MAX]

#中继
bash <(curl -Ls https://github.com/zmlu/easy-sing-box/raw/main/tunnel-final.sh?_=$(date +%s)) [SERVER_PORT]
bash <(curl -Ls https://github.com/zmlu/easy-sing-box/raw/main/tunnel-middle.sh?_=$(date +%s)) <CENTRAL_API> <RANDOM_PORT_MIN> <RANDOM_PORT_MAX> <RANDOM_PORT_MAX> <FINAL_SERVER_IP> <FINAL_SERVER_PORT> <FINAL_SERVER_PWD>
```

### XanMod 内核的安装

```shell
#更新系统
sudo apt update && sudo apt upgrade

#添加并注册 APT 存储库
sudo apt install gnupg
echo 'deb http://deb.xanmod.org releases main' | sudo tee /etc/apt/sources.list.d/xanmod-kernel.list
wget -qO - https://dl.xanmod.org/gpg.key | sudo apt-key --keyring /etc/apt/trusted.gpg.d/xanmod-kernel.gpg add -

#更新 apt 软件包索引
sudo apt update

#检查CPU支持内核版本
#根据输出的内容，你可以清楚地看到v2、v3或v4的标识，据此选择对应的 XanMod 内核
awk -f <(wget -O - https://dl.xanmod.org/check_x86-64_psabi.sh)

#安装内核
sudo apt install linux-xanmod-edge-x64v3

#重启
reboot

#查看所有内核
dpkg --list | egrep -i --color 'linux-image|linux-headers'

#删除内核（请根据上面命令中输出结果，修改下面的命令）
sudo apt remove linux-image-5.10.0-26-amd64

#删除内核配置文件（请根据上面命令中输出结果，修改下面的命令） 
sudo apt purge linux-image-amd64

#查看到的所有内核列表中： 前面标记ii的，即为内核。其中linux-headers为当前使用的启动内核，linux-image为当前系统中安装的内核；前面标记rc的，为已被删除的内核所留存的配置文件。

#更新系统软件包并清除未使用的依赖项
sudo apt-get update
sudo apt-get autoremove

#更新 GRUB 配置
sudo update-grub

#使用下面这个基于xanmod 内核的一键脚本进行优化：
wget https://raw.githubusercontent.com/honorcnboy/BlogDatas/main/VpsScript/Optimization-v2.sh && chmod +x ./Optimization-v2.sh && sudo bash ./Optimization-v2.sh
```

#### 验证安装

```shell
cat /proc/version

uname -mrs

modinfo tcp_bbr
```

### 开启 bbr

```shell
wget --no-check-certificate -O /opt/bbr.sh https://raw.githubusercontent.com/zmlu/across/master/bbr.sh && chmod 755 /opt/bbr.sh && /opt/bbr.sh
```