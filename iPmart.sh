
#!/bin/bash

echo "                 
══════════════════════════════════════════════════════════════════════════════════════
        ____                             _     _                                     
    ,   /    )                           /|   /                                  /   
-------/____/---_--_----__---)__--_/_---/-| -/-----__--_/_-----------__---)__---/-__-
  /   /        / /  ) /   ) /   ) /    /  | /    /___) /   | /| /  /   ) /   ) /(    
_/___/________/_/__/_(___(_/_____(_ __/___|/____(___ _(_ __|/_|/__(___/_/_____/___\__

══════════════════════════════════════════════════════════════════════════════════════"

echo "                 
══════════════════════════════════════════════════════════════════════════════════════
                        SERVER IP=$(hostname -I | awk '{print $1}')
				
			SERVER COUNTRY=$(curl -sS "http://ip-api.com/json/$SERVER_IP" | jq -r '.country')
				
			SERVER ISP=$(curl -sS "http://ip-api.com/json/$SERVER_IP" | jq -r '.isp')
══════════════════════════════════════════════════════════════════════════════════════"

setup_waterwall_service() {
    cat > /etc/systemd/system/iPmart.service << EOF
[Unit]
Description=iPmart Service
After=network.target

[Service]
ExecStart=/root/Network/iPmart
WorkingDirectory=/root/Network
Restart=always
RestartSec=5
User=root
StandardOutput=null
StandardError=null

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable iPmart
    systemctl start iPmart
}

while true; do
    echo "Please choose Number:"
    echo "1. Iran "
    echo "2. Kharej "
    echo "3. Uninstall"
    echo "0. Back"

    read -p "Enter your choice: " choice
    if [[ "$choice" -eq 1 || "$choice" -eq 2 ]]; then
        apt update
        sleep 0.5
        SSHD_CONFIG_FILE="/etc/ssh/sshd_config"
        CURRENT_PORT=$(grep -E '^(#Port |Port )' "$SSHD_CONFIG_FILE")

        if [[ "$CURRENT_PORT" != "Port 22" && "$CURRENT_PORT" != "#Port 22" ]]; then
            sudo sed -i -E 's/^(#Port |Port )[0-9]+/Port 22/' "$SSHD_CONFIG_FILE"
            echo "SSH Port has been updated to Port 22."
            sudo systemctl restart sshd
            sudo service ssh restart
        fi
        sleep 0.5
        mkdir /root/Network
        cd /root/Network
        wget https://github.com/iPmartNetwork/iPmart/releases/download/v1.0/iPmart-linux-64.zip
        apt install unzip -y
        unzip iPmart-linux-64.zip
        sleep 0.5
        chmod +x iPmart
        sleep 0.5
        rm iPmart-linux-64.zip
        cat > core.json << EOF
{
    "log": {
        "path": "log/",
        "core": {
            "loglevel": "DEBUG",
            "file": "core.log",
            "console": true
        },
        "network": {
            "loglevel": "DEBUG",
            "file": "network.log",
            "console": true
        },
        "dns": {
            "loglevel": "SILENT",
            "file": "dns.log",
            "console": false
        }
    },
    "dns": {},
    "misc": {
        "workers": 0,
        "ram-profile": "server",
        "libs-path": "libs/"
    },
    "configs": [
        "config.json"
    ]
}
EOF
        public_ip=$(wget -qO- https://api.ipify.org)
        echo "Your Server IPv4 is: $public_ip"
    fi

    if [ "$choice" -eq 1 ]; then
        echo "You chose Iran."
        read -p "enter Kharej Ipv4: " ip_remote
        read -p "Enter the SNI (default: ipmart.shop): " input_sni
        HOSTNAME=${input_sni:-ipmart.shop}
        cat > config.json << EOF
{
    "name": "reverse_reality_server_multiport",
    "nodes": [
        {
            "name": "users_inbound",
            "type": "TcpListener",
            "settings": {
                "address": "0.0.0.0",
                "port": [443,65535],
                "nodelay": true
            },
            "next": "header"
        },
        {
            "name": "header",
            "type": "HeaderClient",
            "settings": {
                "data": "src_context->port"
            },
            "next": "bridge2"
        },
        {
            "name": "bridge2",
            "type": "Bridge",
            "settings": {
                "pair": "bridge1"
            }
        },
        {
            "name": "bridge1",
            "type": "Bridge",
            "settings": {
                "pair": "bridge2"
            }
        },
        {
            "name": "reverse_server",
            "type": "ReverseServer",
            "settings": {},
            "next": "bridge1"
        },
        {
            "name": "reality_server",
            "type": "RealityServer",
            "settings": {
                "destination": "reality_dest",
                "password": "02249001"
            },
            "next": "reverse_server"
        },
        {
            "name": "kharej_inbound",
            "type": "TcpListener",
            "settings": {
                "address": "0.0.0.0",
                "port": 443,
                "nodelay": true,
                "whitelist": [
                    "$ip_remote/32"
                ]
            },
            "next": "reality_server"
        },
        {
            "name": "reality_dest",
            "type": "TcpConnector",
            "settings": {
                "nodelay": true,
                "address": "$HOSTNAME",
                "port": 443
            }
        }
    ]
}
EOF
        sleep 0.5
        setup_waterwall_service
        sleep 0.5
        echo "Iran IPv4 is: $public_ip"
        echo "Kharej IPv4 is: $ip_remote"
        echo "SNI $HOSTNAME"
        echo "Iran Setup Successfully Created "
    elif [ "$choice" -eq 2 ]; then
        echo "You chose Kharej."
        read -p "enter Iran Ip: " ip_remote
        read -p "Enter the SNI (default: iPmart.shop): " input_sni
        HOSTNAME=${input_sni:-ipmart.shop}
        cat > config.json << EOF
{
    "name": "reverse_reality_client_multiport",
    "nodes": [
        {
            "name": "outbound_to_core",
            "type": "TcpConnector",
            "settings": {
                "nodelay": true,
                "address": "127.0.0.1",
                "port": "dest_context->port"
            }
        },
        {
            "name": "header",
            "type": "HeaderServer",
            "settings": {
                "override": "dest_context->port"
            },
            "next": "outbound_to_core"
        },
        {
            "name": "bridge1",
            "type": "Bridge",
            "settings": {
                "pair": "bridge2"
            },
            "next": "header"
        },
        {
            "name": "bridge2",
            "type": "Bridge",
            "settings": {
                "pair": "bridge1"
            },
            "next": "reverse_client"
        },
        {
            "name": "reverse_client",
            "type": "ReverseClient",
            "settings": {
                "minimum-unused": 16
            },
            "next": "reality_client"
        },
        {
            "name": "reality_client",
            "type": "RealityClient",
            "settings": {
                "sni": "$HOSTNAME",
                "password": "02249001"
            },
            "next": "outbound_to_iran"
        },
        {
            "name": "outbound_to_iran",
            "type": "TcpConnector",
            "settings": {
                "nodelay": true,
                "address": "$ip_remote",
                "port": 443
            }
        }
    ]
}
EOF
        sleep 0.5
        setup_waterwall_service
        sleep 0.5
        echo "Kharej IPv4 is: $public_ip"
        echo "Iran IPv4 is: $ip_remote"
        echo "SNI $HOSTNAME"
        echo "Kharej Setup Successfully Created "
    elif [ "$choice" -eq 3 ]; then
        sudo systemctl stop iPmart
        sudo systemctl disable iPmart
        rm -rf /etc/systemd/system/iPmart.service
        pkill -f iPmart
        rm -rf /root/Network

        echo "Removed"
    elif [ "$choice" -eq 0 ]; then
        echo "Exit"
        break
    else
        echo "Invalid choice. Please try again."
    fi
done
