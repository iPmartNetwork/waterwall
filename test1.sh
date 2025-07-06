#!/bin/bash

# Color Codes
Purple='\033[0;35m'
Cyan='\033[0;36m'
White='\033[0;96m'
RED='\033[0;31m'
NC='\033[0m'

clear
echo -e "${Purple}
══════════════════════════════════════════════════════════════════════════════════════
        ____                             _     _                                     
    ,   /    )                           /|   /                                  /   
-------/____/---_--_----__---)__--_/_---/-| -/-----__--_/_-----------__---)__---/-__-
  /   /        / /  ) /   ) /   ) /    /  | /    /___) /   | /| /  /   ) /   ) /(    
_/___/________/_/__/_(___(_/_____(_ __/___|/____(___ _(_ __|/_|/__(___/_/_____/___\__

══════════════════════════════════════════════════════════════════════════════════════"
${NC}"

# Detect system architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
  ASSET_NAME="Waterwall_Linux_X64_gcc.zip"
elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
  ASSET_NAME="Waterwall_Linux_ARM64.zip"
else
  echo -e "${RED}Unsupported architecture: $ARCH${NC}"
  exit 1
fi

# Get latest WaterWall release URL
get_latest_url() {
  curl -s https://api.github.com/repos/radkesvat/WaterWall/releases/latest |
    jq -r ".assets[] | select(.name == \"$ASSET_NAME\") | .browser_download_url"
}

# Download and extract binary
install_waterwall() {
  mkdir -p /root/RRT && cd /root/RRT
  apt install -y unzip jq curl

  read -p "Install latest version? (y/n): " choice
  if [[ "$choice" =~ ^[Yy]$ ]]; then
    URL=$(get_latest_url)
  else
    read -p "Enter version (e.g., v1.37): " version
    URL=$(curl -s "https://api.github.com/repos/radkesvat/WaterWall/releases/tags/$version" |
      jq -r ".assets[] | select(.name == \"$ASSET_NAME\") | .browser_download_url")
  fi

  if [[ -z "$URL" ]]; then
    echo -e "${RED}Download URL not found.${NC}"
    exit 1
  fi

  echo -e "${Cyan}Downloading from: $URL${NC}"
  curl -L "$URL" -o "$ASSET_NAME"
  unzip -o "$ASSET_NAME" >/dev/null
  [[ -f ./bin/waterwall ]] && mv ./bin/waterwall ./waterwall
  chmod +x waterwall
  rm -f "$ASSET_NAME"
}

# Create systemd service
setup_service() {
  cat > /etc/systemd/system/waterwall.service <<EOF
[Unit]
Description=WaterWall Tunnel Service
After=network.target

[Service]
ExecStart=/root/RRT/waterwall run core.json
WorkingDirectory=/root/RRT
Restart=always
RestartSec=3
User=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable waterwall
  systemctl restart waterwall
}

# Configure core.json
generate_core_json() {
  cat > core.json <<EOF
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
}

# Generate config.json for IRAN
config_iran() {
  public_ip=$(wget -qO- https://api.ipify.org)
  read -p "Enter Foreign IP: " foreign_ip
  read -p "Enter SNI (default: ipmart.network): " input_sni
  sni=${input_sni:-ipmart.network}

  cat > config.json <<EOF
{
  "name": "reverse_reality_server",
  "nodes": [
    {
      "name": "kharej_whitelist",
      "type": "TcpListener",
      "settings": {
        "address": "0.0.0.0",
        "port": 443,
        "whitelist": [ "$foreign_ip/32" ],
        "nodelay": true
      },
      "next": "reality"
    },
    {
      "name": "reality",
      "type": "RealityServer",
      "settings": {
        "destination": "bridge_dest",
        "password": "2249002AHS"
      },
      "next": "reverse"
    },
    {
      "name": "reverse",
      "type": "ReverseServer",
      "settings": {},
      "next": "bridge1"
    },
    {
      "name": "bridge1",
      "type": "Bridge",
      "settings": {
        "pair": "bridge2"
      }
    },
    {
      "name": "bridge2",
      "type": "Bridge",
      "settings": {
        "pair": "bridge1"
      }
    },
    {
      "name": "bridge_dest",
      "type": "TcpConnector",
      "settings": {
        "nodelay": true,
        "address": "$sni",
        "port": 443
      }
    }
  ]
}
EOF

  echo -e "${Cyan}IRAN setup complete. Public IP: $public_ip, SNI: $sni${NC}"
}

# Generate config.json for KHAREJ
config_kharej() {
  public_ip=$(wget -qO- https://api.ipify.org)
  read -p "Enter Iran IP: " iran_ip
  read -p "Enter SNI (default: ipmart.network): " input_sni
  sni=${input_sni:-ipmart.network}

  cat > config.json <<EOF
{
  "name": "reverse_reality_client",
  "nodes": [
    {
      "name": "tcp_out",
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
      "next": "tcp_out"
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
      "next": "reverse"
    },
    {
      "name": "reverse",
      "type": "ReverseClient",
      "settings": {
        "minimum-unused": 16
      },
      "next": "reality"
    },
    {
      "name": "reality",
      "type": "RealityClient",
      "settings": {
        "sni": "$sni",
        "password": "2249002AHS"
      },
      "next": "tcp_to_iran"
    },
    {
      "name": "tcp_to_iran",
      "type": "TcpConnector",
      "settings": {
        "nodelay": true,
        "address": "$iran_ip",
        "port": 443
      }
    }
  ]
}
EOF

  echo -e "${Cyan}KHAREJ setup complete. Public IP: $public_ip, SNI: $sni${NC}"
}

# Main menu
while true; do
  echo -e "${Purple}1) Setup for IRAN\n2) Setup for KHAREJ\n3) Uninstall\n0) Exit${NC}"
  read -p "Choice: " opt
  case $opt in
    1)
      install_waterwall
      generate_core_json
      config_iran
      setup_service
      read -p "Press Enter to continue..."
      ;;
    2)
      install_waterwall
      generate_core_json
      config_kharej
      setup_service
      read -p "Press Enter to continue..."
      ;;
    3)
      systemctl stop waterwall
      systemctl disable waterwall
      rm -f /etc/systemd/system/waterwall.service
      pkill -f waterwall
      rm -rf /root/RRT
      echo -e "${RED}WaterWall Uninstalled.${NC}"
      read -p "Press Enter to continue..."
      ;;
    0) exit 0 ;;
    *) echo "Invalid." ;;
  esac
done
