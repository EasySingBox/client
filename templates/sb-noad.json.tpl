{
  "log": {
    "level": "warn",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "dns-remote",
        "address": "https://8.8.8.8/dns-query",
        "detour": "Proxy"
      },
      {
        "tag": "dns-local",
        "address": "local"
      },
      {
        "tag": "dns-china",
        "address": "https://8.8.8.8/dns-query",
        "detour": "Proxy",
        "client_subnet": "42.194.8.0"
      },
      {
        "tag": "dns-fakeip",
        "address": "fakeip"
      },
      {
        "tag": "dns-block",
        "address": "rcode://name_error"
      }
    ],
    "rules": [
      {
        "query_type": "PTR",
        "server": "dns-block"
      },
      {
        "domain": [
          "airwallex.cc",
          "zmlu.me"
        ],
        "server": "dns-local"
      },
      {
        "rule_set": "ads",
        "server": "dns-block"
      },
      {
        "query_type": [
          "A",
          "AAAA"
        ],
        "rule_set": [
          "netflix",
          "netflixip"
        ],
        "server": "dns-fakeip",
        "rewrite_ttl": 1
      },
      {
        "rule_set": "echemi",
        "server": "dns-local"
      },
      {
        "rule_set": [
          "private",
          "privateip",
          "applications",
          "bilibili",
          "apple-cn",
          "cn",
          "cnip",
          "mydirect"
        ],
        "server": "dns-china"
      },
      {
        "query_type": [
          "A",
          "AAAA"
        ],
        "server": "dns-fakeip",
        "rewrite_ttl": 1
      }
    ],
    "final": "dns-remote",
    "reverse_mapping": true,
    "fakeip": {
      "enabled": true,
      "inet4_range": "240.0.0.0/4",
      "inet6_range": "5f00::/16"
    },
    "independent_cache": true
  },
  "inbounds": [
    {
      "type": "tun",
      "tag": "tun-in",
      "inet4_address": "172.18.0.1/30",
      "inet6_address": "2001:db8:1::1/126",
      "auto_route": true,
      "strict_route": true,
      "inet4_route_exclude_address": [
        "10.0.0.0/8",
        "17.0.0.0/8",
        "192.168.0.0/16"
      ],
      "inet6_route_exclude_address": [
        "fc00::/7",
        "fe80::/10"
      ],
      "exclude_package": [
        "com.taobao.taobao",
        "com.taobao.trip",
        "me.ele",
        "com.dianping.v1",
        "com.eg.android.AlipayGphone",
        "com.cainiao.wireless",
        "com.alibaba.android.rimet",
        "com.tencent.mobileqq",
        "com.tencent.qqmusic",
        "com.tencent.mm",
        "com.tencent.weread",
        "com.tencent.tmgp.sgame",
        "com.tencent.karaoke",
        "com.sankuai.meituan",
        "com.taobao.idlefish",
        "com.MobileTicket",
        "battymole.trainticket",
        "com.xunmeng.pinduoduo",
        "com.jingdong.app.mall",
        "ctrip.android.view",
        "com.sina.weibo",
        "com.ss.android.ugc.aweme",
        "com.tencent.android.qqdownloader",
        "com.youku.phone",
        "com.qiyi.video",
        "com.tencent.qqlive",
        "com.baidu.BaiduMap",
        "com.autonavi.minimap",
        "com.sdu.didi.psnger",
        "com.netease.cloudmusic",
        "com.ximalaya.ting.android",
        "com.xingin.xhs",
        "com.alicloud.databox",
        "com.jd.jrapp",
        "com.umpay.qingdaonfc",
        "cn.gov.pbc.dcep",
        "com.qdznjt.qdtc.jtjt",
        "com.cnspeedtest.globalspeed",
        "cn.futu.trader",
        "com.unionpay",
        "com.xiaomi.router",
        "com.jin10",
        "com.tencent.wetype",
        "com.thestore.main",
        "com.huawei.smarthome",
        "com.tmri.app.main",
        "com.server.auditor.ssh.client"
      ],
      "stack": "gvisor",
      "platform": {
        "http_proxy": {
          "enabled": true,
          "server": "127.0.0.1",
          "server_port": 7890,
          "bypass_domain": [
            "localhost",
            "*.local",
            "sequoia.apple.com",
            "seed-sequoia.siri.apple.com",
            "push.apple.com",
            "talk.google.com",
            "mtalk.google.com",
            "alt1-mtalk.google.com",
            "alt2-mtalk.google.com",
            "alt3-mtalk.google.com",
            "alt4-mtalk.google.com",
            "alt5-mtalk.google.com",
            "alt6-mtalk.google.com",
            "alt7-mtalk.google.com",
            "alt8-mtalk.google.com"
          ]
        }
      },
      "sniff": true,
      "sniff_override_destination": true
    },
    {
      "type": "mixed",
      "tag": "mixed-in",
      "listen": "127.0.0.1",
      "listen_port": 7890,
      "sniff": true,
      "sniff_override_destination": true
    },
    {
      "type": "direct",
      "tag": "dns-in",
      "listen": "127.0.0.1",
      "listen_port": 1053,
      "sniff": true,
      "sniff_override_destination": true
    }
  ],
  "outbounds": [
    {
      "tag": "Proxy",
      "type": "selector",
      "outbounds": [
        "h2",
        "tuic",
        "reality"
      ],
      "interrupt_exist_connections": true
    },
    {
      "type": "hysteria2",
      "tag": "h2",
      "server": "{{ server_ip }}",
      "server_port": {{ h2_port }},
      "obfs": {},
      "password": "{{ password }}",
      "tls": {
        "enabled": true,
        "server_name": "www.bing.com",
        "insecure": true,
        "alpn": [
          "h3"
        ]
      }
    },
    {
      "type": "tuic",
      "tag": "tuic",
      "server": "{{ server_ip }}",
      "server_port": {{ tuic_port }},
      "uuid": "{{ password }}",
      "password": "{{ password }}",
      "tls": {
        "enabled": true,
        "server_name": "www.bing.com",
        "insecure": true,
        "alpn": [
          "h3"
        ]
      }
    },
    {
      "type": "vless",
      "tag": "reality",
      "server": "{{ server_ip }}",
      "server_port": {{ reality_port }},
      "uuid": "{{ password }}",
      "flow": "xtls-rprx-vision",
      "tls": {
        "enabled": true,
        "utls": {
          "enabled": true,
          "fingerprint": "chrome"
        },
        "reality": {
          "enabled": true,
          "public_key": "{{ reality_pbk }}",
          "short_id": "{{ reality_sid }}"
        },
        "server_name": "www.yahoo.com",
        "insecure": true
      }
    },
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    },
    {
      "type": "dns",
      "tag": "dns-out"
    }
  ],
  "route": {
    "rules": [
      {
        "port": 22,
        "outbound": "direct"
      },
      {
        "ip_cidr": "1.12.12.12/32",
        "outbound": "direct"
      },
      {
        "domain": [
          "airwallex.cc",
          "zmlu.me"
        ],
        "outbound": "direct"
      },
      {
        "ip_cidr": "8.8.8.8/32",
        "outbound": "Proxy"
      },
      {
        "rule_set": "ads",
        "outbound": "block"
      },
      {
        "inbound": "dns-in",
        "outbound": "dns-out"
      },
      {
        "protocol": "dns",
        "port": [
          53,
          853
        ],
        "outbound": "dns-out"
      },
      {
        "protocol": "stun",
        "rule_set": [
          "bilibili",
          "apple-cn",
          "cn",
          "cnip",
          "mydirect"
        ],
        "outbound": "direct"
      },
      {
        "protocol": "stun",
        "outbound": "Proxy"
      },
      {
        "rule_set": [
          "netflix",
          "netflixip",
          "myproxy"
        ],
        "outbound": "Proxy"
      },
      {
        "rule_set": [
          "applications",
          "private",
          "privateip",
          "echemi",
          "bilibili",
          "apple-cn",
          "cn",
          "cnip",
          "mydirect"
        ],
        "outbound": "direct"
      }
    ],
    "rule_set": [
      {
        "type": "remote",
        "tag": "echemi",
        "format": "source",
        "url": "http://{{ server_ip }}/{{ www_dir_random_id }}/echemi.json",
        "download_detour": "direct",
        "update_interval": "24h0m0s"
      },
      {
        "type": "remote",
        "tag": "mydirect",
        "format": "source",
        "url": "http://{{ server_ip }}/{{ www_dir_random_id }}/mydirect.json",
        "download_detour": "direct",
        "update_interval": "24h0m0s"
      },
      {
        "type": "remote",
        "tag": "myproxy",
        "format": "source",
        "url": "http://{{ server_ip }}/{{ www_dir_random_id }}/myproxy.json",
        "download_detour": "direct",
        "update_interval": "24h0m0s"
      },
      {
        "type": "remote",
        "tag": "cn",
        "format": "binary",
        "url": "https://cdn.jsdelivr.net/gh/DustinWin/ruleset_geodata@sing-box-ruleset/cn.srs",
        "download_detour": "direct",
        "update_interval": "24h0m0s"
      },
      {
        "type": "remote",
        "tag": "cnip",
        "format": "binary",
        "url": "https://cdn.jsdelivr.net/gh/DustinWin/ruleset_geodata@sing-box-ruleset/cnip.srs",
        "download_detour": "direct",
        "update_interval": "24h0m0s"
      },
      {
        "type": "remote",
        "tag": "netflix",
        "format": "binary",
        "url": "https://cdn.jsdelivr.net/gh/DustinWin/ruleset_geodata@sing-box-ruleset/netflix.srs",
        "download_detour": "direct",
        "update_interval": "24h0m0s"
      },
      {
        "type": "remote",
        "tag": "netflixip",
        "format": "binary",
        "url": "https://cdn.jsdelivr.net/gh/DustinWin/ruleset_geodata@sing-box-ruleset/netflixip.srs",
        "download_detour": "direct",
        "update_interval": "24h0m0s"
      },
      {
        "type": "remote",
        "tag": "private",
        "format": "binary",
        "url": "https://cdn.jsdelivr.net/gh/DustinWin/ruleset_geodata@sing-box-ruleset/private.srs",
        "download_detour": "direct",
        "update_interval": "24h0m0s"
      },
      {
        "type": "remote",
        "tag": "privateip",
        "format": "binary",
        "url": "https://cdn.jsdelivr.net/gh/DustinWin/ruleset_geodata@sing-box-ruleset/privateip.srs",
        "download_detour": "direct",
        "update_interval": "24h0m0s"
      },
      {
        "type": "remote",
        "tag": "bilibili",
        "format": "binary",
        "url": "https://cdn.jsdelivr.net/gh/DustinWin/ruleset_geodata@sing-box-ruleset/bilibili.srs",
        "download_detour": "direct",
        "update_interval": "24h0m0s"
      },
      {
        "type": "remote",
        "tag": "applications",
        "format": "binary",
        "url": "https://cdn.jsdelivr.net/gh/DustinWin/ruleset_geodata@sing-box-ruleset/applications.srs",
        "download_detour": "direct",
        "update_interval": "24h0m0s"
      },
      {
        "type": "remote",
        "tag": "apple-cn",
        "format": "binary",
        "url": "https://cdn.jsdelivr.net/gh/DustinWin/ruleset_geodata@sing-box-ruleset/apple-cn.srs",
        "download_detour": "direct",
        "update_interval": "24h0m0s"
      },
      {
        "type": "remote",
        "tag": "ads",
        "format": "binary",
        "url": "https://cdn.jsdelivr.net/gh/DustinWin/ruleset_geodata@sing-box-ruleset/ads.srs",
        "download_detour": "direct",
        "update_interval": "24h0m0s"
      }
    ],
    "final": "Proxy",
    "auto_detect_interface": true,
    "override_android_vpn": true
  }
}
