{
  "log": {
    "level": "warn",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "dns",
        "address": "{{ client_sb_remote_dns }}",
        "address_resolver": "dns-resolver",
        "detour": "direct"
      },
      {
        "tag": "dns-resolver",
        "address": "1.1.1.1",
        "detour": "direct"
      }
    ],
    "rules": [
      {
        "outbound": "any",
        "server": "dns"
      }
    ],
    "independent_cache": true,
    "strategy": "ipv4_only"
  },
  "inbounds": [
    {
      "type": "hysteria2",
      "tag": "hy2",
      "listen": "::",
      "listen_port": {{ h2_port }},
      "sniff": true,
      "sniff_override_destination": true,
      "ignore_client_bandwidth": true,
      "users": [
        {
          "name": "user-jacob",
          "password": "{{ password }}"
        },
        {
          "name": "user-wgcf",
          "password": "{{ password }}-warp"
        }
      ],
      "tls": {
        "enabled": true,
        "alpn": "h3",
        "certificate_path": "/etc/sing-box/cert.pem",
        "key_path": "/etc/sing-box/private.key"
      },
      "obfs": {
        "type": "salamander",
        "password": "{{ h2_obfs_password }}"
      }
    },
    {
      "type": "tuic",
      "tag": "tuic5",
      "listen": "::",
      "listen_port": {{ tuic_port }},
      "sniff": true,
      "sniff_override_destination": true,
      "users": [
        {
          "uuid": "{{ password }}",
          "password": "{{ password }}"
        }
      ],
      "congestion_control": "bbr",
      "tls": {
        "enabled": true,
        "alpn": "h3",
        "certificate_path": "/etc/sing-box/cert.pem",
        "key_path": "/etc/sing-box/private.key"
      }
    },
    {
      "type": "vless",
      "tag": "vless",
      "listen": "::",
      "listen_port": {{ reality_port }},
      "sniff": true,
      "sniff_override_destination": true,
      "users": [
        {
          "uuid": "{{ password }}",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "www.yahoo.com",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "www.yahoo.com",
            "server_port": 443
          },
          "private_key": "{{ reality_private_key }}",
          "short_id": "{{ reality_sid }}"
        }
      },
      "multiplex": {
        "enabled": false,
        "padding": true,
        "brutal": {
          "enabled": false,
          "up_mbps": 1024,
          "down_mbps": 1024
        }
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct",
      "domain_strategy": "ipv4_only"
    },
    {
      "type": "direct",
      "tag": "wgcf",
      "routing_mark": 51888,
      "domain_strategy": "ipv6_only"
    }
  ],
  "route": {
    "rules": [
      {
        "action": "sniff"
      },
      {
        "protocol": "dns",
        "action": "hijack-dns"
      },
      {
        "protocol": [
          "stun"
        ],
        "outbound": "direct"
      },
      {
        "rule_set": [
          "netflix",
          "netflixip"
        ],
        "outbound": "wgcf"
      },
      {
        "inbound": "hy2",
        "auth_user": "user-wgcf",
        "outbound": "direct"
      }
    ],
    "rule_set": [
      {
        "type": "remote",
        "tag": "netflix",
        "format": "binary",
        "url": "https://github.com/DustinWin/ruleset_geodata/raw/sing-box-ruleset/netflix.srs",
        "update_interval": "24h0m0s"
      },
      {
        "type": "remote",
        "tag": "netflixip",
        "format": "binary",
        "url": "https://github.com/DustinWin/ruleset_geodata/raw/sing-box-ruleset/netflixip.srs",
        "update_interval": "24h0m0s"
      }
    ],
    "final": "direct"
  }
}
