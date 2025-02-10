mode: rule
ipv6: true
log-level: silent
allow-lan: false
mixed-port: 7890
unified-delay: true
tcp-concurrent: true
external-controller: :9090

geodata-mode: true
geox-url:
  geoip: "http://{{ server_ip }}/{{ www_dir_random_id }}/geoip.dat"
  geosite: "http://{{ server_ip }}/{{ www_dir_random_id }}/geosite.dat"
  mmdb: "http://{{ server_ip }}/{{ www_dir_random_id }}/Country.mmdb"
geo-auto-update: true
geo-update-interval: 24

find-process-mode: strict
keep-alive-interval: 1800
global-client-fingerprint: firefox
profile:
  store-selected: true
  store-fake-ip: true

sniffer:
  enable: true
  sniff:
    HTTP:
      ports: [80, 8080-8880]
      override-destination: true
    TLS:
      ports: [443, 8443]
    QUIC:
      ports: [443, 8443]
  skip-domain:
    - 'Mijia Cloud'
    - 'dlg.io.mi.com'

tun:
  enable: true
  stack: system
  dns-hijack:
    - 8.8.8.8:53
    - tcp://8.8.8.8:53
    - any:53
    - tcp://any:53
    - tls://any:853
  auto-route: true
  auto-redir: true
  auto-detect-interface: true

dns:
  cache-algorithm: arc
  enable: true
  prefer-h3: true
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  listen: 0.0.0.0:53
  ipv6: true
  nameserver-policy:
    'geosite:geolocation-!cn':
      - '{{ client_sb_remote_dns }}#Proxy'
  default-nameserver:
    - 119.29.29.29
    - 'https://1.1.1.1/dns-query'
    - 8.8.8.8
    - system
  nameserver:
    - 119.29.29.29
    - https://doh.pub/dns-query
  fake-ip-filter:
    - '*.lan'
    - '*.linksys.com'
    - '*.linksyssmartwifi.com'
    - '*.msftconnecttest.com'
    - '*.msftncsi.com'
    - 'time.*.com'
    - 'time.*.gov'
    - 'time.*.edu.cn'
    - 'time1.*.com'
    - 'time2.*.com'
    - 'time3.*.com'
    - 'time4.*.com'
    - 'time5.*.com'
    - 'time6.*.com'
    - 'time7.*.com'
    - 'ntp.*.com'
    - 'ntp.*.com'
    - 'ntp1.*.com'
    - 'ntp2.*.com'
    - 'ntp3.*.com'
    - 'ntp4.*.com'
    - 'ntp5.*.com'
    - 'ntp6.*.com'
    - 'ntp7.*.com'
    - '*.time.edu.cn'
    - '*.ntp.org.cn'
    - '+.pool.ntp.org'
    - 'time1.cloud.tencent.com'
    - '+.music.163.com'
    - '*.126.net'
    - 'musicapi.taihe.com'
    - 'music.taihe.com'
    - 'songsearch.kugou.com'
    - 'trackercdn.kugou.com'
    - '*.kuwo.cn'
    - 'api-jooxtt.sanook.com'
    - 'api.joox.com'
    - 'joox.com'
    - '+.y.qq.com'
    - '+.music.tc.qq.com'
    - 'aqqmusic.tc.qq.com'
    - '+.stream.qqmusic.qq.com'
    - '*.xiami.com'
    - '+.music.migu.cn'
    - '+.srv.nintendo.net'
    - '*.n.n.srv.nintendo.net'
    - '+.stun.playstation.net'
    - 'xbox.*.*.microsoft.com'
    - '*.*.xboxlive.com'
    - 'localhost.ptlogin2.qq.com'
    - 'proxy.golang.org'
    - 'lens.l.google.com'
    - '*.mcdn.bilivideo.cn'
    - '*.qq.com'
    - '+.stun.*.*'
    - '+.stun.*.*.*'
    - '+.stun.*.*.*.*'
    - '+.stun.*.*.*.*.*'
    - '+.echemi.*'
    - '+.echemi.*.*'
    - '+.echemi.*.*.*'
    - 'codeup.aliyun.com'

proxies:
- name: "h2"
  type: hysteria2
  server: {{ server_ip }}
  port: {{ h2_port }}
  password: {{ password }}
  up: "1000 Mbps"
  down: "1000 Mbps"
  obfs: salamander
  obfs-password: {{ h2_obfs_password }}
  fast-open: true
  sni: www.bing.com
  skip-cert-verify: true
  alpn:
    - h3
- name: tuic
  server: {{ server_ip }}
  port: {{ tuic_port }}
  type: tuic
  uuid: {{ password }}
  password: {{ password }}
  fast-open: true
  sni: www.bing.com
  skip-cert-verify: true
  alpn:
    - h3
- name: "reality"
  type: vless
  cipher: none
  server: {{ server_ip }}
  port: {{ reality_port }}
  udp: true
  uuid: {{ password }}
  network: tcp
  flow: xtls-rprx-vision
  reality-opts:
    public-key: {{ reality_pbk }}
    short-id: {{ reality_sid }}
  tls: true
  servername: yahoo.com
  client-fingerprint: firefox

proxy-groups:
- name: Proxy
  type: select
  proxies:
  - Auto
  - h2
  - h2-warp
  - tuic
  - reality
- name: "Auto"
  type: fallback
  proxies:
  - h2
  - tuic
  - reality
  - h2-warp
  url: 'https://www.gstatic.com/generate_204'
  interval: 300

rules:
- IP-CIDR,127.0.0.0/8,DIRECT
- IP-CIDR,192.168.0.0/16,DIRECT
- geosite,private,DIRECT
- geoip,netflix,Proxy
- geoip,google,Proxy
- geosite,geolocation-!cn,Proxy
- MATCH,DIRECT
