#!/usr/bin/env bash
set -e

INSTALL_DIR="/opt/waterwall"
BIN_NAME="Waterwall"
CONFIG_PATH="$INSTALL_DIR/config.json"

function remove_service() {
  echo "🧹 Removing WaterWall..."

  read -rp "Enter the service name to remove (e.g. waterwall-client): " service_name
  sudo systemctl stop "$service_name" || true
  sudo systemctl disable "$service_name" || true
  sudo rm -f "/etc/systemd/system/$service_name.service"
  sudo systemctl daemon-reload

  echo "Do you want to delete all WaterWall files from $INSTALL_DIR? (yes/no): "
  read answer
  if [[ "$answer" =~ ^[Yy] ]]; then
    sudo rm -rf "$INSTALL_DIR"
    echo "✅ Deleted $INSTALL_DIR"
  fi

  echo "✅ Service '$service_name' removed."
  exit 0
}

if [[ "$1" == "--remove" ]]; then
  remove_service
fi

echo "=== 💧 WaterWall Reverse Tunnel Setup (Multi-Port Supported) ==="

read -rp "Is this server INSIDE Iran? (yes/no): " is_iran
read -rp "Enter shared secret key: " secret

if [[ "$is_iran" =~ ^[Yy] ]]; then
  role="server"
  read -rp "Enter one or more ports separated by commas (e.g. 443,8443,9443): " port_list
  read -rp "Choose a systemd service name (e.g. waterwall-server): " service_name
else
  role="client"
  read -rp "Enter the Iranian server's public IP: " iran_ip
  read -rp "Enter the connection port (e.g. 443): " port
  read -rp "Choose a systemd service name (e.g. waterwall-client): " service_name
fi

# Clean install dir
sudo rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

# Generate config
echo "📝 Creating config.json..."

if [[ "$role" == "server" ]]; then
  ports_clean=$(echo "$port_list" | sed 's/ //g')
  ports_array=$(echo "$ports_clean" | sed 's/,/","/g')

  cat > "$CONFIG_PATH" <<EOF
{
  "node_type": "server",
  "listen": {
    "tcp": [":${ports_array}"]
  },
  "tunnel": {
    "type": "reverse",
    "secret": "$secret"
  }
}
EOF
else
  cat > "$CONFIG_PATH" <<EOF
{
  "node_type": "client",
  "reverse_proxy": {
    "connect": "$iran_ip:$port",
    "secret": "$secret"
  },
  "proxy": {
    "socks": ":1080"
  }
}
EOF
fi

# Architecture detection
ARCH=$(uname -m)
BINARY_URL=""
echo "Detected architecture: $ARCH"

if [[ "$ARCH" == "x86_64" ]]; then
  echo "Choose binary for x86_64:"
  echo "1) GCC (recommended)"
  echo "2) GCC (old CPUs)"
  echo "3) Clang"
  read -rp "Select version [1-3]: " option
  case "$option" in
    1) BINARY_URL="https://github.com/radkesvat/WaterWall/releases/download/v1.39/Waterwall_linux_x64_gcc.zip" ;;
    2) BINARY_URL="https://github.com/radkesvat/WaterWall/releases/download/v1.39/Waterwall_linux_X64_gcc_old_cpus.zip" ;;
    3) BINARY_URL="https://github.com/radkesvat/WaterWall/releases/download/v1.39/Waterwall_linux_x64_clang.zip" ;;
    *) echo "Invalid option"; exit 1 ;;
  esac
elif [[ "$ARCH" == "aarch64" ]]; then
  echo "Choose binary for ARM64:"
  echo "1) Normal CPU"
  echo "2) Old CPU"
  read -rp "Select version [1-2]: " option
  case "$option" in
    1) BINARY_URL="https://github.com/radkesvat/WaterWall/releases/download/v1.39/Waterwall_linux_arm64.zip" ;;
    2) BINARY_URL="https://github.com/radkesvat/WaterWall/releases/download/v1.39/Waterwall_linux_arm64_old_cpu.zip" ;;
    *) echo "Invalid option"; exit 1 ;;
  esac
else
  echo "❌ Unsupported architecture: $ARCH"
  exit 1
fi

# Download and extract full ZIP
echo "⬇️ Downloading from: $BINARY_URL"
curl -L "$BINARY_URL" -o /tmp/waterwall.zip
unzip -o /tmp/waterwall.zip -d "$INSTALL_DIR"
chmod +x "$INSTALL_DIR/$BIN_NAME"

# Confirm core.json exists
if [[ ! -f "$INSTALL_DIR/core.json" ]]; then
  echo "❌ ERROR: Missing core.json. Please make sure ZIP file contains all components."
  exit 1
fi

# systemd service
SERVICE_FILE="/etc/systemd/system/$service_name.service"
echo "🛠️ Creating systemd service: $service_name"

cat <<EOF | sudo tee "$SERVICE_FILE" > /dev/null
[Unit]
Description=WaterWall Reverse Tunnel ($role)
After=network.target

[Service]
ExecStart=$INSTALL_DIR/$BIN_NAME -c $CONFIG_PATH
Restart=always
RestartSec=5
User=root
WorkingDirectory=$INSTALL_DIR

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable "$service_name"
sudo systemctl restart "$service_name"

echo "✅ WaterWall service '$service_name' installed and running."
sudo systemctl status "$service_name" --no-pager
