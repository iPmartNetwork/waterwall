#!/usr/bin/env bash
set -e

SERVICE_BASE_NAME="waterwall"
INSTALL_DIR="$HOME/waterwall-bin"
BIN_NAME="waterwall"
WALL_VERSION="v1.39"
RELEASE_BASE="https://github.com/radkesvat/WaterWall/releases/download/$WALL_VERSION"

function detect_architecture_and_url() {
  ARCH=$(uname -m)
  case "$ARCH" in
    aarch64 | arm64)
      echo "✅ Detected: ARM64"
      FILE_URL="$RELEASE_BASE/Waterwall_linux_arm64.zip"
      ;;
    x86_64)
      echo "✅ Detected: x86_64"
      echo "Select binary type:"
      echo "1) Clang (recommended modern)"
      echo "2) GCC (default)"
      echo "3) GCC for older CPUs"
      read -p "➡️ Choose option [1-3]: " OPT
      case "$OPT" in
        1) FILE_URL="$RELEASE_BASE/Waterwall_linux_x64_clang.zip" ;;
        2) FILE_URL="$RELEASE_BASE/Waterwall_linux_x64_gcc.zip" ;;
        3) FILE_URL="$RELEASE_BASE/Waterwall_linux_X64_gcc_old_cpus.zip" ;;
        *) echo "❌ Invalid option"; exit 1 ;;
      esac
      ;;
    *)
      echo "❌ Unsupported architecture: $ARCH"
      exit 1
      ;;
  esac
}

function download_and_extract_binary() {
  sudo apt update
  sudo apt install -y unzip curl

  mkdir -p "$INSTALL_DIR"
  cd "$INSTALL_DIR"

  ZIP_NAME="waterwall.zip"

  echo "🌐 Downloading binary from:"
  echo "$FILE_URL"
  curl -L -o "$ZIP_NAME" "$FILE_URL"

  echo "📦 Extracting..."
  unzip -o "$ZIP_NAME"

  if [[ -f Waterwall ]]; then
    chmod +x Waterwall
    mv -f Waterwall waterwall
  fi

  if [[ ! -f waterwall ]]; then
    echo "❌ Failed to extract waterwall binary"
    exit 1
  fi

  chmod +x waterwall
  echo "✅ Extracted and ready: $(pwd)/waterwall"
}

function create_service() {
  local role="$1"
  local password="$2"
  local ports="$3"
  local ip="$4"
  local port_args=""
  local log_file="$HOME/waterwall_${role}_$(date +%s).log"
  local core_bin="$INSTALL_DIR/waterwall"

  for P in ${ports//,/ }; do
    port_args+=" --lport $P"
  done

  [[ "$role" == "kharej" ]] && ip_flag="--ip $ip" || ip_flag=""

  local exec_cmd="$core_bin --role $role $port_args $ip_flag --password $password --multi-port --keep-ufw --keep-os-limit --default-core"

  local service_file="/etc/systemd/system/$SERVICE_BASE_NAME-$role.service"
  echo "📝 Creating systemd service [$SERVICE_BASE_NAME-$role.service]"

  sudo bash -c "cat > $service_file" <<EOF
[Unit]
Description=WaterWall Reverse Tunnel ($role)
After=network.target

[Service]
Type=simple
ExecStart=$exec_cmd
Restart=always
RestartSec=5
StandardOutput=append:$log_file
StandardError=append:$log_file

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reexec
  sudo systemctl daemon-reload
  sudo systemctl enable "$SERVICE_BASE_NAME-$role.service"
  sudo systemctl restart "$SERVICE_BASE_NAME-$role.service"

  echo "✅ Service started: $SERVICE_BASE_NAME-$role"
}

function wait_for_wtun0() {
  echo "⏳ Waiting for interface wtun0 to become available..."
  for i in {1..10}; do
    if ip link show wtun0 > /dev/null 2>&1; then
      echo "✅ Tunnel interface wtun0 is now active."
      return
    fi
    sleep 1
  done
  echo "❌ Interface wtun0 did not appear after 10 seconds."
  echo "⚠️ Check logs with: cat ~/waterwall_*.log"
}

function setup_tunnel() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🔧 WaterWall Reverse Tunnel Setup (Binary v1.39)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  while true; do
    read -p "🌍 Is this server in Iran or Outside? (iran/kharej): " ROLE
    [[ "$ROLE" == "iran" || "$ROLE" == "kharej" ]] && break
  done

  read -p "🔑 Enter shared tunnel password: " PASSWORD
  [[ "$ROLE" == "kharej" ]] && read -p "📡 Enter IP of Iranian server: " SERVER_IP
  read -p "📦 Enter comma-separated ports (e.g. 9000,9001): " PORTS

  detect_architecture_and_url
  download_and_extract_binary
  sudo ip link set dev wtun0 mtu 1400 || true
  create_service "$ROLE" "$PASSWORD" "$PORTS" "$SERVER_IP"
  wait_for_wtun0
}

function manage_service() {
  local cmd="$1"
  for role in iran kharej; do
    svc="$SERVICE_BASE_NAME-$role.service"
    if systemctl list-units --full -all | grep -q "$svc"; then
      echo "🔧 $cmd: $svc"
      sudo systemctl "$cmd" "$svc"
    fi
  done
}

function rebuild_systemd_services() {
  echo "🛠 Rebuilding systemd service files with --default-core"
  for role in iran kharej; do
    local file="/etc/systemd/system/$SERVICE_BASE_NAME-$role.service"
    if [[ -f "$file" ]]; then
      echo "🔄 Updating $file"
      sudo systemctl stop "$SERVICE_BASE_NAME-$role.service" || true
      sudo rm -f "$file"
      sudo systemctl disable "$SERVICE_BASE_NAME-$role.service" || true

      read -p "🔑 Enter shared tunnel password for [$role]: " password
      [[ "$role" == "kharej" ]] && read -p "📡 Enter IP of Iranian server: " server_ip
      read -p "📦 Enter comma-separated ports: " ports

      create_service "$role" "$password" "$ports" "$server_ip"
    fi
  done
}

function uninstall_all() {
  echo "🧹 Removing WaterWall Services and Binaries..."
  for role in iran kharej; do
    svc="$SERVICE_BASE_NAME-$role.service"
    sudo systemctl stop "$svc" || true
    sudo systemctl disable "$svc" || true
    sudo rm -f "/etc/systemd/system/$svc"
  done

  sudo systemctl daemon-reload
  sudo systemctl reset-failed

  echo "🗑️ Removing binary files from $INSTALL_DIR"
  rm -rf "$INSTALL_DIR"

  echo "✅ Uninstallation complete."
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔁 WaterWall Tunnel Script Menu"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1) setup            - Create and start tunnel"
echo "2) start            - Start tunnel service"
echo "3) stop             - Stop tunnel service"
echo "4) status           - Check tunnel status"
echo "5) uninstall        - Remove tunnel + files"
echo "6) rebuild-systemd  - Recreate systemd configs"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
read -p "➡️ Choose action: " ACTION

case "$ACTION" in
  1|setup)            setup_tunnel ;;
  2|start)            manage_service start ;;
  3|stop)             manage_service stop ;;
  4|status)           manage_service status ;;
  5|uninstall)        uninstall_all ;;
  6|rebuild-systemd)  rebuild_systemd_services ;;
  *)                  echo "❌ Invalid option"; exit 1 ;;
esac
