{
  "log": {
    "level": "warn",
    "timestamp": true
  },
  "experimental": {
    "clash_api": {
      "external_controller": "127.0.0.1:9090"
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
        "address": "https://1.1.1.1/dns-query",
        "detour": "Proxy"
      },
      {
        "tag": "dns-local",
        "address": "local"
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
        "package_name": [
          {{ exclude_package }}
        ],
        "action": "route",
        "server": "dns-local"
      },
      {{ ad_dns_rule }}
      {
        "query_type": [
          "A"
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
          "A"
        ],
        "server": "dns-fakeip"
      }
    ],
    "final": "dns-remote",
    "strategy": "ipv4_only",
    "reverse_mapping": true,
    "fakeip": {
      "enabled": true,
      "inet4_range": "240.0.0.0/4"
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
    }
  ],
  "outbounds": [
    {
      "tag": "Proxy",
      "type": "selector",
      "outbounds": [
        "h2 ({{ vps_org }})",
        "tuic ({{ vps_org }})",
        "reality ({{ vps_org }})"
      ],
      "interrupt_exist_connections": true
    },
    {
      "type": "hysteria2",
      "tag": "h2 ({{ vps_org }})",
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
      },
      "domain_strategy": "prefer_ipv4",
      "network_strategy": "fallback"
    },
    {
      "type": "tuic",
      "tag": "tuic ({{ vps_org }})",
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
      "domain_strategy": "prefer_ipv4",
      "network_strategy": "fallback"
    },
    {
      "type": "vless",
      "tag": "reality ({{ vps_org }})",
      "server": "{{ server_ip }}",
      "server_port": {{ reality_port }},
      "uuid": "{{ password }}",
      "flow": "",
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
      },
      "packet_encoding": "xudp",
      "multiplex": {
        "enabled": true,
        "protocol": "h2mux",
        "max_connections": 1,
        "min_streams": 4,
        "padding": true,
        "brutal": {
          "enabled": true,
          "up_mbps": 1024,
          "down_mbps": 1024
        }
      },
      "domain_strategy": "prefer_ipv4",
      "network_strategy": "fallback"
    },
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
    "rules": [
      {
        "inbound": "mixed-in",
        "action": "resolve",
        "strategy": "prefer_ipv4"
      },
      {
        "inbound": "mixed-in",
        "action": "sniff",
        "timeout": "1s"
      },
      {
        "protocol": [
          "dtls",
          "ssh",
          "rdp"
        ],
        "outbound": "direct"
      },
      {
        "ip_cidr": [
          "1.1.1.1/32",
          "8.8.8.8/32"
        ],
        "outbound": "Proxy"
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
        "protocol": "stun",
        "rule_set": [
          "cn",
          "cnip",
          "mydirect{{ random_suffix }}"
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
          "myproxy{{ random_suffix }}",
          "microsoft-cn"
        ],
        "outbound": "Proxy"
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
      {{ ad_rule_set }}
      {
        "type": "remote",
        "tag": "microsoft-cn",
        "format": "binary",
        "url": "https://cdn.jsdmirror.com/gh/DustinWin/ruleset_geodata@sing-box-ruleset/microsoft-cn.srs",
        "download_detour": "direct",
        "update_interval": "24h0m0s"
      },
      {
        "type": "remote",
        "tag": "cn",
        "format": "binary",
        "url": "https://cdn.jsdmirror.com/gh/DustinWin/ruleset_geodata@sing-box-ruleset/cn.srs",
        "download_detour": "direct",
        "update_interval": "24h0m0s"
      },
      {
        "type": "remote",
        "tag": "cnip",
        "format": "binary",
        "url": "https://cdn.jsdmirror.com/gh/DustinWin/ruleset_geodata@sing-box-ruleset/cnip.srs",
        "download_detour": "direct",
        "update_interval": "24h0m0s"
      },
      {
        "type": "remote",
        "tag": "netflix",
        "format": "binary",
        "url": "https://cdn.jsdmirror.com/gh/DustinWin/ruleset_geodata@sing-box-ruleset/netflix.srs",
        "download_detour": "direct",
        "update_interval": "24h0m0s"
      },
      {
        "type": "remote",
        "tag": "netflixip",
        "format": "binary",
        "url": "https://cdn.jsdmirror.com/gh/DustinWin/ruleset_geodata@sing-box-ruleset/netflixip.srs",
        "download_detour": "direct",
        "update_interval": "24h0m0s"
      },
      {
        "type": "remote",
        "tag": "private",
        "format": "binary",
        "url": "https://cdn.jsdmirror.com/gh/DustinWin/ruleset_geodata@sing-box-ruleset/private.srs",
        "download_detour": "direct",
        "update_interval": "24h0m0s"
      },
      {
        "type": "remote",
        "tag": "privateip",
        "format": "binary",
        "url": "https://cdn.jsdmirror.com/gh/DustinWin/ruleset_geodata@sing-box-ruleset/privateip.srs",
        "download_detour": "direct",
        "update_interval": "24h0m0s"
      }
    ],
    "final": "Proxy",
    "auto_detect_interface": true,
    "override_android_vpn": true
  }
}