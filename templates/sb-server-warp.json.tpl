{
  "log": {
    "level": "warn",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "hysteria2",
      "tag": "hy2-sb",
      "listen": "::",
      "listen_port": {{ h2_port }},
      "sniff": true,
      "sniff_override_destination": true,
      "ignore_client_bandwidth": true,
      "users": [
        {
          "password": "{{ password }}"
        }
      ],
      "tls": {
        "enabled": true,
        "alpn": "h3",
        "certificate_path": "/etc/sing-box/cert.pem",
        "key_path": "/etc/sing-box/private.key"
      }
    },
    {
      "type": "tuic",
      "tag": "tuic5-sb",
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
      "tag": "vless-sb",
      "listen": "::",
      "listen_port": {{ reality_port }},
      "sniff": true,
      "sniff_override_destination": true,
      "users": [
        {
          "name": "",
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
        "enabled": true,
        "padding": true,
        "brutal": {
          "enabled": true,
          "up_mbps": 1024,
          "down_mbps": 1024
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
      "type": "socks",
      "tag": "socks-out",
      "server": "127.0.0.1",
      "server_port": 40000,
      "version": "5"
    },
    {
      "type": "direct",
      "tag": "socks-out-ipv4",
      "detour": "socks-out",
      "domain_strategy": "ipv4_only"
    }
  ],
  "route": {
    "rules": [
      {
        "rule_set": [
          "netflix",
          "netflixip"
        ],
        "outbound": "socks-out-ipv4"
      },
      {
        "network": [
          "tcp",
          "udp"
        ],
        "port": [
          53,
          80,
          88,
          5000
        ],
        "port_range": "1024:65000",
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
    "final": "socks-out"
  }
}
