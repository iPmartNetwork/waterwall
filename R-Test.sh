#!/bin/bash

set -e

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configs
INSTALL_DIR="/opt/waterwall"
CONFIG_DIR="/etc/waterwall"
SERVICE_NAME="waterwall"
ASSET_NAME=""
DEFAULT_SNI="ipmart.shop"
PASSWORD="2249002AHS"

#  Dependencies
for pkg in curl jq unzip wget; do
  if ! command -v $pkg &>/dev/null; then
    echo -e "${YELLOW}Installing $pkg...${NC}"
    apt-get install -y $pkg || yum install -y $pkg
  fi
done

# Auto-detect architecture

detect_arch_asset() {
  local uname_arch
  uname_arch=$(uname -m)

  case "$uname_arch" in
    x86_64) arch_keywords=("amd64" "x64") ;;
    aarch64) arch_keywords=("arm64" "aarch64") ;;
    armv7* | armhf) arch_keywords=("armv7") ;;
    i386 | i686) arch_keywords=("386" "i386") ;;
    riscv64) arch_keywords=("riscv64") ;;
    mips64el) arch_keywords=("mips64el") ;;
    *) echo -e "${RED}❌ Unsupported architecture: $uname_arch${NC}"; return 1 ;;
  esac

  echo -e "${CYAN}🔍 Detecting compatible release for architecture: $uname_arch${NC}"

  local release_api="https://api.github.com/repos/radkesvat/WaterWall/releases/latest"
  local assets_json=$(curl -s "$release_api")

  for keyword in "${arch_keywords[@]}"; do
    asset_name=$(echo "$assets_json" | jq -r ".assets[] | select(.name | test(\"$keyword\"; \"i\")) | .name" | head -n1)
    if [ -n "$asset_name" ]; then
      asset_url=$(echo "$assets_json" | jq -r ".assets[] | select(.name == \"$asset_name\") | .browser_download_url")
      echo "$asset_name|$asset_url"
      return 0
    fi
  done

  echo -e "${RED}❌ No compatible asset found for architecture $uname_arch${NC}"
  return 1
}

download_waterwall() {
  local url="$1"
  mkdir -p "$INSTALL_DIR"
  cd "$INSTALL_DIR"
  wget -q -O "$ASSET_NAME" "$url"
  unzip -o "$ASSET_NAME"
  chmod +x Waterwall
  rm "$ASSET_NAME"
}

setup_service() {
cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=WaterWall Tunnel
After=network.target

[Service]
ExecStart=$INSTALL_DIR/Waterwall run -c $CONFIG_DIR/core.json
WorkingDirectory=$INSTALL_DIR
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable ${SERVICE_NAME}
  systemctl restart ${SERVICE_NAME}
}

setup_core_json() {
  mkdir -p "$CONFIG_DIR"
  cat > "$CONFIG_DIR/core.json" <<EOF
{
  "log": {
    "path": "log/",
    "core": { "loglevel": "INFO", "file": "core.log", "console": true },
    "network": { "loglevel": "DEBUG", "file": "network.log", "console": true },
    "dns": { "loglevel": "SILENT", "file": "dns.log", "console": false }
  },
  "dns": {},
  "misc": {
    "workers": 0,
    "ram-profile": "server",
    "libs-path": "libs/"
  },
  "configs": [ "$CONFIG_DIR/config.json" ]
}
EOF
}

create_config_iran() {
  local remote_ip="$1"
  local sni="$2"
  cat > "$CONFIG_DIR/config.json" <<EOF
{
  "name": "reverse_server",
  "nodes": [
    { "name": "users_inbound", "type": "TcpListener", "settings": { "address": "0.0.0.0", "port": [443,65535], "nodelay": true }, "next": "header" },
    { "name": "header", "type": "HeaderClient", "settings": { "data": "src_context->port" }, "next": "bridge2" },
    { "name": "bridge2", "type": "Bridge", "settings": { "pair": "bridge1" } },
    { "name": "bridge1", "type": "Bridge", "settings": { "pair": "bridge2" } },
    { "name": "reverse_server", "type": "ReverseServer", "settings": {}, "next": "bridge1" },
    { "name": "reality_server", "type": "RealityServer", "settings": { "destination": "reality_dest", "password": "$PASSWORD" }, "next": "reverse_server" },
    { "name": "kharej_inbound", "type": "TcpListener", "settings": { "address": "0.0.0.0", "port": 443, "nodelay": true, "whitelist": ["$remote_ip/32"] }, "next": "reality_server" },
    { "name": "reality_dest", "type": "TcpConnector", "settings": { "nodelay": true, "address": "$sni", "port": 443 } }
  ]
}
EOF
}

create_config_kharej() {
  local remote_ip="$1"
  local sni="$2"
  cat > "$CONFIG_DIR/config.json" <<EOF
{
  "name": "reverse_client",
  "nodes": [
    { "name": "outbound_to_core", "type": "TcpConnector", "settings": { "nodelay": true, "address": "127.0.0.1", "port": "dest_context->port" } },
    { "name": "header", "type": "HeaderServer", "settings": { "override": "dest_context->port" }, "next": "outbound_to_core" },
    { "name": "bridge1", "type": "Bridge", "settings": { "pair": "bridge2" }, "next": "header" },
    { "name": "bridge2", "type": "Bridge", "settings": { "pair": "bridge1" }, "next": "reverse_client" },
    { "name": "reverse_client", "type": "ReverseClient", "settings": { "minimum-unused": 16 }, "next": "reality_client" },
    { "name": "reality_client", "type": "RealityClient", "settings": { "sni": "$sni", "password": "$PASSWORD" }, "next": "outbound_to_iran" },
    { "name": "outbound_to_iran", "type": "TcpConnector", "settings": { "nodelay": true, "address": "$remote_ip", "port": 443 } }
  ]
}
EOF
}

# 🗺 Main Menu
main_menu() {
  clear
  echo -e "${CYAN}WaterWall Auto Installer${NC}"
  echo "1) Iran Server Setup"
  echo "2) Foreign Server Setup"
  echo "3) Uninstall"
  echo "0) Exit"
  read -p "Choose: " opt

  case "$opt" in
    1)
      read -p "Enter foreign server IP: " remote_ip
      read -p "SNI (default: $DEFAULT_SNI): " sni_input
      sni=${sni_input:-$DEFAULT_SNI}
      result=$(detect_arch_asset) || exit 1
      ASSET_NAME=$(echo "$result" | cut -d'|' -f1)
      ASSET_URL=$(echo "$result" | cut -d'|' -f2)
      download_waterwall "$ASSET_URL"
      setup_core_json
      create_config_iran "$remote_ip" "$sni"
      setup_service
      echo -e "${GREEN}✅ Iran node ready. Public IP: $(wget -qO- https://api.ipify.org)${NC}"
      ;;
    2)
      read -p "Enter Iran server IP: " remote_ip
      read -p "SNI (default: $DEFAULT_SNI): " sni_input
      sni=${sni_input:-$DEFAULT_SNI}
      result=$(detect_arch_asset) || exit 1
      ASSET_NAME=$(echo "$result" | cut -d'|' -f1)
      ASSET_URL=$(echo "$result" | cut -d'|' -f2)
      download_waterwall "$ASSET_URL"
      setup_core_json
      create_config_kharej "$remote_ip" "$sni"
      setup_service
      echo -e "${GREEN}✅ Foreign node ready. Public IP: $(wget -qO- https://api.ipify.org)${NC}"
      ;;
    3)
      systemctl stop ${SERVICE_NAME}
      systemctl disable ${SERVICE_NAME}
      rm -f /etc/systemd/system/${SERVICE_NAME}.service
      rm -rf "$INSTALL_DIR" "$CONFIG_DIR"
      echo -e "${YELLOW}Uninstalled WaterWall.${NC}"
      ;;
    0) exit ;;
    *) echo "Invalid"; sleep 1; main_menu ;;
  esac
}

main_menu
