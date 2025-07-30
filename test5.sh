#!/usr/bin/env bash
set -euo pipefail

green="\033[0;32m"
red="\033[0;31m"
reset="\033[0m"

INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/waterwall"
CONFIG_FILE="$CONFIG_DIR/core.json"
SERVICE_FILE="/etc/systemd/system/waterwall.service"

# === Ensure unzip is installed ===
if ! command -v unzip &>/dev/null; then
  echo -e "${green}📦 Installing unzip...${reset}"
  if command -v apt &>/dev/null; then
    apt update && apt install -y unzip
  elif command -v dnf &>/dev/null; then
    dnf install -y unzip
  elif command -v yum &>/dev/null; then
    yum install -y unzip
  else
    echo -e "${red}❌ No package manager found.${reset}"
    exit 1
  fi
fi

# === Menu ===
echo -e "${green}🚀 WaterWall Setup Menu${reset}"
echo "1) Install & Start Tunnel"
echo "2) Remove Tunnel Config Only"
echo "3) Full Uninstall (Binary + Config + Service)"
read -rp "Select option [1-3]: " CHOICE

if [[ "$CHOICE" == "2" ]]; then
  echo -e "${red}🗑 Removing core.json...${reset}"
  systemctl stop waterwall || true
  rm -f "$CONFIG_FILE"
  echo -e "${green}✅ Tunnel config removed.${reset}"
  exit 0
elif [[ "$CHOICE" == "3" ]]; then
  echo -e "${red}🧹 Uninstalling WaterWall...${reset}"
  systemctl stop waterwall || true
  systemctl disable waterwall || true
  rm -f "$INSTALL_DIR/WaterWall"
  rm -rf "$CONFIG_DIR"
  rm -f "$SERVICE_FILE"
  systemctl daemon-reexec
  echo -e "${green}✅ Fully uninstalled.${reset}"
  exit 0
elif [[ "$CHOICE" != "1" ]]; then
  echo -e "${red}❌ Invalid selection.${reset}"
  exit 1
fi

# === Detect architecture ===
detect_arch() {
  ARCH_RAW=$(uname -m)
  CPU_FLAGS=$(lscpu | grep -i "flags" || echo "")
  case "$ARCH_RAW" in
    x86_64)
      if echo "$CPU_FLAGS" | grep -qi avx2; then echo "x64_gcc"
      else echo "x64_gcc_old_cpus"; fi ;;
    aarch64)
      if echo "$CPU_FLAGS" | grep -qi asimd; then echo "arm64"
      else echo "arm64_old_cpu"; fi ;;
    *) echo "❌ Unsupported architecture: $ARCH_RAW"; exit 1 ;;
  esac
}
ARCH=$(detect_arch)
echo -e "${green}✅ Detected architecture: $ARCH${reset}"

# === User Input ===
echo "🌐 Choose server role:"
select ROLE in "iran" "foreign"; do [[ -n "$ROLE" ]] && break; done
read -rp "🔑 Shared password: " PASSWORD
if [[ "$ROLE" == "foreign" ]]; then
  read -rp "🌍 Iran server IP: " REMOTE_IP
fi
read -rp "🔁 Number of tunnels (default: 1): " TUNNELS
TUNNELS="${TUNNELS:-1}"
read -rp "📍 Base port (default: 2249): " PORT_BASE
PORT_BASE="${PORT_BASE:-2249}"

# === Download and Install ===
mkdir -p "$CONFIG_DIR"
BIN_URL="https://github.com/radkesvat/WaterWall/releases/download/v1.39/Waterwall_linux_${ARCH}.zip"
echo -e "${green}📥 Downloading binary...${reset}"
curl -L "$BIN_URL" -o /tmp/waterwall.zip
BIN_NAME=$(unzip -l /tmp/waterwall.zip | awk '/[Ww]aterwall$/{print $NF}' | head -n1)
if [[ -z "$BIN_NAME" ]]; then
  echo -e "${red}❌ Binary not found in zip.${reset}"
  exit 1
fi
unzip -o /tmp/waterwall.zip -d /tmp
mv "/tmp/$BIN_NAME" "$INSTALL_DIR/WaterWall"
chmod +x "$INSTALL_DIR/WaterWall"

# === Build core.json ===
echo '{"name":"waterwall","nodes":[' > "$CONFIG_FILE"
for i in $(seq 0 $((TUNNELS - 1))); do
  PORT=$((PORT_BASE + i))
  if [[ "$ROLE" == "iran" ]]; then
    cat >> "$CONFIG_FILE" <<EOF
    {
      "name":"listener_$i",
      "type":"TcpListener",
      "settings":{"address":"0.0.0.0","port":$PORT,"nodelay":true},
      "next":"reverse_$i"
    },
    {
      "name":"reverse_$i",
      "type":"ReverseServer",
      "settings":{},
      "next":"bridge_$i"
    },
    {
      "name":"bridge_$i",
      "type":"Bridge",
      "settings":{"pair":"remote_bridge_$i"}
    },
EOF
  else
    cat >> "$CONFIG_FILE" <<EOF
    {
      "name":"remote_bridge_$i",
      "type":"Bridge",
      "settings":{"pair":"bridge_$i"},
      "next":"reverse_client_$i"
    },
    {
      "name":"reverse_client_$i",
      "type":"ReverseClient",
      "settings":{"minimum-unused":4},
      "next":"tcp_$i"
    },
    {
      "name":"tcp_$i",
      "type":"TcpConnector",
      "settings":{"address":"${REMOTE_IP}","port":$PORT,"nodelay":true}
    },
EOF
  fi
done
# clean trailing comma
sed -i '$ s/},/}/' "$CONFIG_FILE"
echo "]}" >> "$CONFIG_FILE"

# === Create systemd service with core.json ===
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=WaterWall Tunnel (core.json)
After=network.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/WaterWall --core $CONFIG_FILE --password $PASSWORD
Restart=on-failu
