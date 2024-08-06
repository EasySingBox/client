## easy-sing-box

### OS
Ubuntu 22+

### 安装

```shell
bash <(curl -Ls https://github.com/zmlu/easy-sing-box/raw/main/install.sh)
```

### 开启 bbr

```shell
wget --no-check-certificate -O /opt/bbr.sh https://raw.githubusercontent.com/zmlu/across/master/bbr.sh
chmod 755 /opt/bbr.sh
/opt/bbr.sh
```

### Netflix解锁

安装 WARP socks5，使用默认端口 40000

```shell
bash <(curl -sSL https://raw.githubusercontent.com/zmlu/x-ui-scripts/main/install_warp_proxy.sh)
```