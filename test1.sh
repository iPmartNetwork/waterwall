#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="/etc/waterwall"
CONFIG_FILE="$CONFIG_DIR/core.json"
SERVICE_FILE="/etc/systemd/system/waterwall.service"
BIN_PATH="/usr/local/bin/WaterWall"
green="\033[0;32m"
red="\033[0;31m"
reset="\033[0m"

# === Ensure unzip installed ===
if ! command -v unzip &>/dev/null; then
  echo -e "${green}Installing unzip...${reset}"
  apt update && apt install -y unzip || dnf install -y unzip || yum install -y unzip || true
fi

# === Architecture detection ===
detect_arch() {
  ARCH_RAW=$(uname -m)
  FLAGS=$(lscpu | grep -i flags || echo "")
  case "$ARCH_RAW" in
    x86_64) [[ "$FLAGS" =~ avx2 ]] && echo "x64_gcc" || echo "x64_gcc_old_cpus" ;;
    aarch64) [[ "$FLAGS" =~ asimd ]] && echo "arm64" || echo "arm64_old_cpu" ;;
    *) echo "Unsupported arch: $ARCH_RAW" && exit 1 ;;
  esac
}

ARCH=$(detect_arch)
echo -e "${green}✅ Detected architecture: $ARCH${reset}"

# === Menu ===
echo -e "${green}WaterWall Tunnel Setup${reset}"
echo "1) Setup Tunnel (iran or foreign)"
echo "2) Remove Tunnel Config Only"
echo "3) Full Uninstall"
read -rp "Select [1-3]: " CHOICE

if [[ "$CHOICE" == "2" ]]; then
  echo -e "${red}Removing core.json...${reset}"
  systemctl stop waterwall || true
  rm -f "$CONFIG_FILE"
  echo -e "${green}✅ Config removed.${reset}"
  exit 0
elif [[ "$CHOICE" == "3" ]]; then
  echo -e "${red}Full uninstall...${reset}"
  systemctl stop waterwall || true
  systemctl disable waterwall || true
  rm -f "$BIN_PATH" "$SERVICE_FILE"
  rm -rf "$CONFIG_DIR"
  systemctl daemon-reexec
  echo -e "${green}✅ Uninstalled completely.${reset}"
  exit 0
elif [[ "$CHOICE" != "1" ]]; then
  echo -e "${red}Invalid selection.${reset}"
  exit 1
fi

# === Inputs ===
echo "🌍 Choose server role:"
select ROLE in "iran" "foreign"; do [[ -n "$ROLE" ]] && break; done

read -rp "🔑 Shared password: " PASSWORD
read -rp "🔁 Number of tunnels (default 1): " TUNNELS
TUNNELS="${TUNNELS:-1}"
read -rp "📍 Base port (default 2249): " PORT_BASE
PORT_BASE="${PORT_BASE:-2249}"

if [[ "$ROLE" == "foreign" ]]; then
  read -rp "🌐 IP of Iranian server: " IRAN_IP
fi

# === Download binary ===
BIN_URL="https://github.com/radkesvat/WaterWall/releases/download/v1.39/Waterwall_linux_${ARCH}.zip"
echo -e "${green}📥 Downloading WaterWall binary...${reset}"
curl -L "$BIN_URL" -o /tmp/waterwall.zip
BIN_NAME=$(unzip -l /tmp/waterwall.zip | awk '/[Ww]aterwall$/{print $NF}' | head -n1)
unzip -o /tmp/waterwall.zip -d /tmp
mv "/tmp/$BIN_NAME" "$BIN_PATH"
chmod +x "$BIN_PATH"

# === Generate core.json ===
mkdir -p "$CONFIG_DIR"
echo '{"name":"waterwall","nodes":[' > "$CONFIG_FILE"

for i in $(seq 0 $((TUNNELS - 1))); do
  PORT=$((PORT_BASE + i))
  if [[ "$ROLE" == "iran" ]]; then
    cat >> "$CONFIG_FILE" <<EOF
    {
      "name": "listener_$i",
      "type": "TcpListener",
      "settings": { "address": "0.0.0.0", "port": $PORT, "nodelay": true },
      "next": "reverse_$i"
    },
    {
      "name": "reverse_$i",
      "type": "ReverseServer",
      "settings": {},
      "next": "bridge_$i"
    },
    {
      "name": "bridge_$i",
      "type": "Bridge",
      "settings": { "pair": "remote_bridge_$i" }
    },
EOF
  else
    cat >> "$CONFIG_FILE" <<EOF
    {
      "name": "remote_bridge_$i",
      "type": "Bridge",
      "settings": { "pair": "bridge_$i" },
      "next": "reverse_client_$i"
    },
    {
      "name": "reverse_client_$i",
      "type": "ReverseClient",
      "settings": { "minimum-unused": 4 },
      "next": "tcp_$i"
    },
    {
      "name": "tcp_$i",
      "type": "TcpConnector",
      "settings": { "address": "$IRAN_IP", "port": $PORT, "nodelay": true }
    },
EOF
  fi
done

# Remove trailing comma and close JSON
sed -i '$ s/},/}/' "$CONFIG_FILE"
echo "]}" >> "$CONFIG_FILE"

# === Create systemd service ===
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=WaterWall Auto Tunnel
After=network.target

[Service]
Type=simple
ExecStart=$BIN_PATH --core $CONFIG_FILE --password $PASSWORD
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# === Start service ===
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable waterwall
systemctl restart waterwall

echo -e "${green}✅ WaterWall is active and persistent.${reset}"
