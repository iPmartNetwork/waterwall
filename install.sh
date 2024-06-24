#!/bin/bash

echo -e "${Purple}               
══════════════════════════════════════════════════════════════════════════════════════
        ____                             _     _                                     
    ,   /    )                           /|   /                                  /   
-------/____/---_--_----__---)__--_/_---/-| -/-----__--_/_-----------__---)__---/-__-
  /   /        / /  ) /   ) /   ) /    /  | /    /___) /   | /| /  /   ) /   ) /(    
_/___/________/_/__/_(___(_/_____(_ __/___|/____(___ _(_ __|/_|/__(___/_/_____/___\__

══════════════════════════════════════════════════════════════════════════════════════"

Black='\033[0;30m'        # Black
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Blue='\033[0;34m'         # Blue
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan
NC='\033[0m'              # NC
White='\033[0;96m'        # White
 
    if ! command -v unzip &> /dev/null; then
        # Check if the system is using apt package manager
        if command -v apt-get &> /dev/null; then
            echo -e "${Purple}unzip is not installed. Installing...${NC}"
            sleep 1
            sudo apt-get update
            sudo apt-get install -y unzip
        else
            echo -e "${Purple}Error: Unsupported package manager. Please install unzip manually.${NC}\n"
            read -p "Press any key to continue..."
            exit 1
        fi
    fi
    (crontab -l 2>/dev/null; echo "0 0 * * * /etc/systemd/system/waterwall.service") | crontab -
setup_waterwall_service() {
    cat > /etc/systemd/system/waterwall.service << EOF
[Unit]
Description=Waterwall Service
After=network.target

[Service]
ExecStart=/root/RRT/Waterwall
WorkingDirectory=/root/RRT
Restart=always
RestartSec=5
User=root
StandardOutput=null
StandardError=null

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable waterwall
    systemctl start waterwall
}

while true; do
    echo -e "${Purple}Select an option:${NC}"
    echo -e "${White}1. IRAN ${NC}"
    echo -e "${Cyan}2. KHAREJ ${NC}"
    echo -e "${White}3. Uninstall${NC}"
    echo -e "${Cyan}0. Exit ${NC}"

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
    # Check operating system
    if [[ $(uname) == "Linux" ]]; then
        ARCH=$(uname -m)
        DOWNLOAD_URL=$(curl -sSL https://api.github.com/repos/radkesvat/WaterWall/releases/latest | grep -o "https://.*$ARCH.*linux.*zip" | head -n 1)
    else
        echo -e "${Purple}Unsupported operating system.${NC}"
        sleep 1
        exit 1
    fi
        sleep 0.5
        mkdir /root/RRT
        cd /root/RRT
        wget https://github.com/radkesvat/WaterWall/releases/download/v1.21/Waterwall-linux-64.zip
        apt install unzip -y
        unzip Waterwall-linux-64.zip
        sleep 0.5
        chmod +x Waterwall
        sleep 0.5
        rm Waterwall-linux-64.zip
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
        echo -e "${Cyan}You chose Iran.${NC}"
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
                "password": "2249002AHS"
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
        echo -e "${Cyan}Iran IPv4 is: $public_ip${NC}"
        echo -e "${Purple}Kharej IPv4 is: $ip_remote${NC}"
        echo -e "${Cyan}SNI $HOSTNAME${NC}"
        echo -e "${Purple}Iran Setup Successfully Created ${NC}"
    elif [ "$choice" -eq 2 ]; then
        echo -e "${Purple}You chose Kharej.${NC}"
        read -p "enter Iran Ip: " ip_remote
        read -p "Enter the SNI (default: ipmart.shop): " input_sni
        HOSTNAME=${input_sni:-ipamart.shop}
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
                "password": "2249002AHS"
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
        echo -e "${Purple}Kharej IPv4 is: $public_ip${NC}"
        echo -e "${Cyan}Iran IPv4 is: $ip_remote${NC}"
        echo -e "${Purple}SNI $HOSTNAME${NC}"
        echo -e "${Cyan}Kharej Setup Successfully Created ${NC}"
    elif [ "$choice" -eq 3 ]; then
        sudo systemctl stop waterwall
        sudo systemctl disable waterwall
        rm -rf /etc/systemd/system/waterwall.service
        pkill -f Waterwall
        rm -rf /root/RRT

        echo "Removed"
    elif [ "$choice" -eq 0 ]; then
        echo "Exit..."
        break
    else
        echo "Invalid choice. Please try again."
    fi
done
