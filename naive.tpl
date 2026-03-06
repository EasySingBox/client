	{
      "type": "naive",
      "tag": "naive-in",
      "listen": "::",
      "listen_port": 443,
      "tcp_fast_open": true,
      "tcp_multi_path": true,
      "quic_congestion_control": "bbr2",
      "users": [
        {
          "username": "user-zmlu",
          "password": "$PASSWORD"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$DOMAIN_NAME",
        "certificate_path": "$CERT_DIR/fullchain.pem",
        "key_path": "$CERT_DIR/privkey.pem",
        "ech": {
          "enabled": false,
          "key": $ECH_KEYS
        }
      },
    }