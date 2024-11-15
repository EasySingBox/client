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
          "uuid": "{{ password }}",
          "flow": ""
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
  ]
}
