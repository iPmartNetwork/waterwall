#!/bin/bash

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

echo "               
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
        sleep 0.5
        mkdir /root/RDT
        cd /root/RDT
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
    "name": "reality_client_multiport",
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
            "next": "my_reality_client"
        },
        {
            "name": "my_reality_client",
            "type": "RealityClient",
            "settings": {
                "sni":"ipmart.shop",
                "password":"22AHS224900"

            },
            "next": "outbound_to_kharej"
        },

        {
            "name": "outbound_to_kharej",
            "type": "TcpConnector",
            "settings": {
                "nodelay": true,
                "address":"$ip_remote",
                "port":443
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
    "name": "reality_server_multiport",
    "nodes": [
        {
            "name": "main_inbound",
            "type": "TcpListener",
            "settings": {
                "address": "0.0.0.0",
                "port": 443,
                "nodelay": true
            },
            "next": "my_reality_server"
        },

        {
            "name": "my_reality_server",
            "type": "RealityServer",
            "settings": {
                "destination":"reality_dest_node",
                "password":"22AHS224900"

            },
            "next": "header_server"
        },
        
        {
            "name": "header_server",
            "type": "HeaderServer",
            "settings": {
                "override": "dest_context->port"
            },
            "next": "final_outbound"
        },

        {
            "name": "final_outbound",
            "type": "TcpConnector",
            "settings": {
                "nodelay": true,
                "address":"127.0.0.1",
                "port":"dest_context->port"

            }
        },

        {
            "name": "reality_dest_node",
            "type": "TcpConnector",
            "settings": {
                "nodelay": true,
                "address":"iPmart.shop",
                "port":443
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
        rm -rf /root/RDT

        echo "Removed"
    elif [ "$choice" -eq 0 ]; then
        echo "Exit..."
        break
    else
        echo "Invalid choice. Please try again."
    fi
done
