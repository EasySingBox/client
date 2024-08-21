mode: rule
ipv6: false
log-level: error
subscribe-url: http://{{ server_ip }}/{{www_dir_random_id}}/st.yaml

script:
  shortcuts:
    quic: network == 'udp' and dst_port == 443
    udp-cn: network == 'udp' and geoip(dst_ip if dst_ip != '' else resolve_ip(host)) == 'CN'

dns:
  follow-rule: true
  ipv6: false
  default-nameserver: null
  nameserver:
    - https://1.1.1.1/dns-query
    - http3://1.1.1.1/dns-query
  skip-cert-verify: true
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
  nameserver-policy:
    'ruleset:cn': system
    'ruleset:mydirect': system
    +.echemi.cc: system
    +.echemi.co: system
    +.echemi.com: system
    +.echemi.net: system
    +.echemi.top: system

hosts:
  www.echemi.co: 8.218.59.124
  www.echemi.top: 8.218.59.124

proxies:
  - alpn:
      - h3
    auth: {{ password }}
    benchmark-url: http://www.apple.com/library/test/success.html
    fast-open: false
    name: h2 ({{ vps_org }})
    port: {{ h2_port }}
    server: {{ server_ip }}
    servername: www.bing.com
    skip-cert-verify: true
    sni: www.bing.com
    tls: true
    type: hysteria2
  - alpn:
      - h3
    benchmark-url: https://www.apple.com/library/test/success.html
    name: tuic ({{ vps_org }})
    password: {{ password }}
    port: {{ tuic_port }}
    server: {{ server_ip }}
    servername: www.bing.com
    skip-cert-verify: true
    sni: www.bing.com
    tls: true
    type: tuic
    uuid: {{ password }}
    version: 5

proxy-groups:
  - name: PROXY
    type: select
    proxies:
      - 'h2 ({{ vps_org }})'
      - 'tuic ({{ vps_org }})'
      - Auto
  - name: Auto
    interval: 120
    lazy: true
    tolerance: 50
    type: url-test
    include-all: true

rule-providers:
  echemi:
    behavior: classical
    format: text
    interval: 86400
    url: http://{{ server_ip }}/{{ www_dir_random_id }}/st_echemi.list
  st_apple:
    behavior: classical
    format: text
    interval: 86400
    url: http://{{ server_ip }}/{{ www_dir_random_id }}/st_apple.list
  mydirect:
    behavior: classical
    format: text
    interval: 86400
    url: http://{{ server_ip }}/{{ www_dir_random_id }}/st_mydirect.list
  myproxy:
    behavior: classical
    format: text
    interval: 86400
    url: http://{{ server_ip }}/{{ www_dir_random_id }}/st_myproxy.list
  cn:
    behavior: domain
    format: text
    interval: 86400
    url: https://cdn.jsdelivr.net/gh/DustinWin/ruleset_geodata@clash-ruleset/cn.list
  cnip:
    behavior: ipcidr
    format: text
    interval: 86400
    url: https://cdn.jsdelivr.net/gh/DustinWin/ruleset_geodata@clash-ruleset/cnip.list
  netflix:
    behavior: domain
    format: text
    interval: 86400
    url: https://cdn.jsdelivr.net/gh/DustinWin/ruleset_geodata@clash-ruleset/netflix.list
  netflixip:
    behavior: ipcidr
    format: text
    interval: 86400
    url: https://cdn.jsdelivr.net/gh/DustinWin/ruleset_geodata@clash-ruleset/netflixip.list
  private:
    behavior: domain
    format: text
    interval: 86400
    url: https://cdn.jsdelivr.net/gh/DustinWin/ruleset_geodata@clash-ruleset/private.list
  privateip:
    behavior: ipcidr
    format: text
    interval: 86400
    url: https://cdn.jsdelivr.net/gh/DustinWin/ruleset_geodata@clash-ruleset/privateip.list

rules:
  - RULE-SET,st_apple,PROXY
  - RULE-SET,netflix,PROXY
  - RULE-SET,netflixip,PROXY,no-resolve
  - RULE-SET,myproxy,PROXY
  - SCRIPT,udp-cn,DIRECT
  - SCRIPT,quic,PROXY
  - IP-CIDR,{{ server_ip }}/32,DIRECT,no-resolve
  - IP-CIDR,127.0.0.0/8,DIRECT,no-resolve
  - SRC-IP-CIDR,192.168.0.0/16,DIRECT,no-resolve
  - DST-PORT,22,DIRECT
  - IP-CIDR,119.29.29.29/32,DIRECT,no-resolve
  - IP-CIDR,8.8.8.8/32,PROXY,no-resolve
  - RULE-SET,privateip,DIRECT,no-resolve
  - RULE-SET,private,DIRECT
  - RULE-SET,echemi,DIRECT
  - RULE-SET,cn,DIRECT
  - RULE-SET,cnip,DIRECT,no-resolve
  - RULE-SET,mydirect,DIRECT
  - MATCH,PROXY

http:
  url-rewrite:
    - ^http?://(www.)?google.com.hk https://www.google.com/ncr 302
    - ^http?://(www.)?g.cn https://www.google.com/ncr 302
    - ^http?://(www.)?google.cn https://www.google.com/ncr 302
  mitm:
    - 'google.com.hk'
    - 'www.google.com.hk'
    - 'g.cn'
    - 'www.g.cn'
    - 'google.cn'
    - 'www.google.cn'
  ca-passphrase: 'C19C006A'
  ca: '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'

