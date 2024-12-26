{
  "log": {
    "level": "warn",
    "timestamp": true
  },
  "experimental": {
    "clash_api": {
      "external_controller": "127.0.0.1:9090",
      "access_control_allow_origin": [
        "http://127.0.0.1",
        "https://yacd.metacubex.one",
        "http://yacd.haishan.me",
        "https://metacubex.github.io"
      ],
      "access_control_allow_private_network": true
    },
    "cache_file": {
      "enabled": true,
      "store_fakeip": true
    }
  },
  "dns": {
    "servers": [
      {
        "tag": "dns-remote",
        "address": "{{ client_sb_remote_dns }}",
        "address_resolver": "dns-resolver",
        "detour": "🚀Proxy"
      },
      {
        "tag": "dns-local",
        "address": "119.29.29.29",
        "detour": "direct"
      },
      {
        "tag": "dns-resolver",
        "address": "1.1.1.1",
        "detour": "🚀Proxy"
      },
      {
        "tag": "dns-fakeip",
        "address": "fakeip"
      }
    ],
    "rules": [
      {
        "clash_mode": "Direct",
        "server": "dns-local"
      },
      {
        "clash_mode": "Global",
        "server": "dns-remote"
      },
      {
        "package_name": [
          {{ exclude_package }}
        ],
        "action": "route",
        "server": "dns-local"
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
        "action": "route",
        "server": "dns-fakeip"
      },
      {
        "rule_set": [
          "private",
          "privateip",
          "echemi{{ random_suffix }}",
          "cn",
          "cnip",
          "mydirect{{ random_suffix }}"
        ],
        "server": "dns-local"
      },
      {
        "query_type": [
          "A",
          "AAAA"
        ],
        "server": "dns-fakeip"
      }
    ],
    "final": "dns-remote",
    "strategy": "ipv4_only",
    "fakeip": {
      "enabled": true,
      "inet4_range": "240.0.0.0/4",
      "inet6_range": "fc00::/18"
    },
    "independent_cache": true
  },
  "inbounds": [
    {
      "type": "tun",
      "tag": "tun-in",
      "address": [
        "172.18.0.1/30",
        "fdfe:dcba:9876::1/126"
      ],
      "auto_route": true,
      "strict_route": true,
      "route_exclude_address": [
        "10.0.0.0/8",
        "17.0.0.0/8",
        "192.168.0.0/16",
        "fc00::/7",
        "fe80::/10"
      ],
      "exclude_package": [
        {{ exclude_package }}
      ],
      "stack": "mixed",
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
      }
    },
    {
      "type": "mixed",
      "tag": "mixed-in",
      "listen": "127.0.0.1",
      "listen_port": 7890
    }
  ],
  "outbounds": [
    {
      "tag": "🚀Proxy",
      "type": "selector",
      "outbounds": [
        "🤖Auto",
        "h2",
        "h2-warp",
        "tuic",
        "reality"
      ],
      "interrupt_exist_connections": true
    },
    {
      "tag": "🤖Auto",
      "type": "urltest",
      "outbounds": [
        "h2",
        "tuic",
        "reality"
      ],
      "tolerance": 500,
      "interrupt_exist_connections": true
    },
    {
      "tag": "ℹ️Info",
      "type": "selector",
      "outbounds": [
        "{{ vps_org }}",
        "{{ country }}"
      ]
    },
    {
      "type": "hysteria2",
      "tag": "h2",
      "server": "{{ server_ip }}",
      "server_port": {{ h2_port }},
      "obfs": {
        "type": "salamander",
        "password": "{{ h2_obfs_password }}"
      },
      "password": "{{ password }}",
      "tls": {
        "enabled": true,
        "server_name": "www.bing.com",
        "insecure": true,
        "alpn": [
          "h3"
        ]
      },
      "tcp_fast_open": true,
      "udp_fragment": true,
      "tcp_multi_path": false,
      "domain_strategy": "ipv4_only"
    },
    {
      "type": "hysteria2",
      "tag": "h2-warp",
      "server": "{{ server_ip }}",
      "server_port": {{ h2_port }},
      "obfs": {
        "type": "salamander",
        "password": "{{ h2_obfs_password }}"
      },
      "password": "{{ password }}-warp",
      "tls": {
        "enabled": true,
        "server_name": "www.bing.com",
        "insecure": true,
        "alpn": [
          "h3"
        ]
      },
      "tcp_fast_open": true,
      "udp_fragment": true,
      "tcp_multi_path": false,
      "domain_strategy": "ipv4_only"
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
      },
      "tcp_fast_open": true,
      "udp_fragment": true,
      "tcp_multi_path": false,
      "domain_strategy": "ipv4_only"
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
          "fingerprint": "firefox"
        },
        "reality": {
          "enabled": true,
          "public_key": "{{ reality_pbk }}",
          "short_id": "{{ reality_sid }}"
        },
        "server_name": "yahoo.com",
        "insecure": true
      },
      "packet_encoding": "xudp",
      "tcp_fast_open": true,
      "udp_fragment": true,
      "tcp_multi_path": false,
      "domain_strategy": "ipv4_only"
    },
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "direct",
      "tag": "{{ vps_org }}"
    },
    {
      "type": "direct",
      "tag": "{{ country }}"
    }
  ],
  "route": {
    "rules": [
      {
        "clash_mode": "Direct",
        "outbound": "direct"
      },
      {
        "clash_mode": "Global",
        "outbound": "🚀Proxy"
      },
      {
        "inbound": "mixed-in",
        "action": "sniff",
        "timeout": "1s"
      },
      {
        "inbound": "tun-in",
        "action": "sniff",
        "timeout": "1s"
      },
      {
        "ip_cidr": [
          "1.1.1.1/32",
          "8.8.8.8/32"
        ],
        "outbound": "🚀Proxy"
      },
      {{ ad_route_rule }}
      {
        "protocol": "dns",
        "port": [
          53,
          853
        ],
        "action": "hijack-dns"
      },
      {
        "protocol": "quic",
        "rule_set": [
          "cn",
          "cnip",
          "mydirect{{ random_suffix }}"
        ],
        "outbound": "direct"
      },
      {
        "protocol": "quic",
        "outbound": "🚀Proxy"
      },
      {
        "rule_set": [
          "netflix",
          "netflixip",
          "myproxy{{ random_suffix }}"
        ],
        "outbound": "🚀Proxy"
      },
      {
        "rule_set": [
          "private",
          "privateip",
          "echemi{{ random_suffix }}",
          "cn",
          "cnip",
          "mydirect{{ random_suffix }}",
          "mywechat{{ random_suffix }}"
        ],
        "outbound": "direct"
      }
    ],
    "rule_set": [
      {
        "type": "remote",
        "tag": "echemi{{ random_suffix }}",
        "format": "source",
        "url": "http://{{ server_ip }}/{{ www_dir_random_id }}/sb_echemi.json",
        "download_detour": "direct",
        "update_interval": "24h0m0s"
      },
      {
        "type": "remote",
        "tag": "mydirect{{ random_suffix }}",
        "format": "source",
        "url": "http://{{ server_ip }}/{{ www_dir_random_id }}/sb_mydirect.json",
        "download_detour": "direct",
        "update_interval": "24h0m0s"
      },
      {
        "type": "remote",
        "tag": "myproxy{{ random_suffix }}",
        "format": "source",
        "url": "http://{{ server_ip }}/{{ www_dir_random_id }}/sb_myproxy.json",
        "download_detour": "direct",
        "update_interval": "24h0m0s"
      },
      {
        "type": "remote",
        "tag": "mywechat{{ random_suffix }}",
        "format": "source",
        "url": "http://{{ server_ip }}/{{ www_dir_random_id }}/sb_wechat.json",
        "download_detour": "direct",
        "update_interval": "24h0m0s"
      },
      {{ ad_rule_set }}
      {
        "type": "remote",
        "tag": "cn",
        "format": "binary",
        "url": "https://github.com/DustinWin/ruleset_geodata/releases/download/sing-box-ruleset/cn.srs",
        "download_detour": "🚀Proxy",
        "update_interval": "24h0m0s"
      },
      {
        "type": "remote",
        "tag": "cnip",
        "format": "binary",
        "url": "https://github.com/DustinWin/ruleset_geodata/releases/download/sing-box-ruleset/cnip.srs",
        "download_detour": "🚀Proxy",
        "update_interval": "24h0m0s"
      },
      {
        "type": "remote",
        "tag": "netflix",
        "format": "binary",
        "url": "https://github.com/DustinWin/ruleset_geodata/releases/download/sing-box-ruleset/netflix.srs",
        "download_detour": "🚀Proxy",
        "update_interval": "24h0m0s"
      },
      {
        "type": "remote",
        "tag": "netflixip",
        "format": "binary",
        "url": "https://github.com/DustinWin/ruleset_geodata/releases/download/sing-box-ruleset/netflixip.srs",
        "download_detour": "🚀Proxy",
        "update_interval": "24h0m0s"
      },
      {
        "type": "remote",
        "tag": "private",
        "format": "binary",
        "url": "https://github.com/DustinWin/ruleset_geodata/releases/download/sing-box-ruleset/private.srs",
        "download_detour": "🚀Proxy",
        "update_interval": "24h0m0s"
      },
      {
        "type": "remote",
        "tag": "privateip",
        "format": "binary",
        "url": "https://github.com/DustinWin/ruleset_geodata/releases/download/sing-box-ruleset/privateip.srs",
        "download_detour": "🚀Proxy",
        "update_interval": "24h0m0s"
      }
    ],
    "final": "🚀Proxy",
    "auto_detect_interface": true,
    "override_android_vpn": true
  }
}