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
      "up_mbps": 500,
      "down_mbps": 500,
      "users": [
        {
          "name": "user-jacob",
          "password": "{{ password }}"
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
      },
      "masquerade": {
        "type": "string",
        "status_code": 500,
        "content": "The server was unable to complete your request. Please try again later. If this problem persists, please contact support. Server logs contain details of this error with request ID: 839-234."
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
        "server_name": "yahoo.com",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "yahoo.com",
            "server_port": 443
          },
          "private_key": "{{ reality_private_key }}",
          "short_id": "{{ reality_sid }}"
        }
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "direct",
      "tag": "wgcf",
      "routing_mark": 51888
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
