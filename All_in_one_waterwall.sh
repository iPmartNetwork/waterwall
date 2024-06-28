#!/bin/bash

# Paths
HOST_PATH="/etc/hosts"
DNS_PATH="/etc/resolv.conf"

# Green, Yellow & Red Messages.
green_msg() {
    tput setaf 2
    echo "[*] ----- $1"
    tput sgr0
}

yellow_msg() {
    tput setaf 3
    echo "[*] ----- $1"
    tput sgr0
}

red_msg() {
    tput setaf 1
    echo "[*] ----- $1"
    tput sgr0
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${Purple}This script must be run as root. Please run it with sudo.${NC}"
        exit 1
    fi
}

fix_etc_hosts(){
  echo
  yellow_msg "Fixing Hosts file."
  sleep 0.5

  cp $HOST_PATH /etc/hosts.bak
  yellow_msg "Default hosts file saved. Directory: /etc/hosts.bak"
  sleep 0.5

  # shellcheck disable=SC2046
  if ! grep -q $(hostname) $HOST_PATH; then
    echo "127.0.1.1 $(hostname)" | sudo tee -a $HOST_PATH > /dev/null
    green_msg "Hosts Fixed."
    echo
    sleep 0.5
  else
    green_msg "Hosts OK. No changes made."
    echo
    sleep 0.5
  fi
}

fix_dns(){
    echo
    yellow_msg "Fixing DNS Temporarily."
    sleep 0.5

    cp $DNS_PATH /etc/resolv.conf.bak
    yellow_msg "Default resolv.conf file saved. Directory: /etc/resolv.conf.bak"
    sleep 0.5

    sed -i '/nameserver/d' $DNS_PATH

    echo "nameserver 8.8.8.8" >> $DNS_PATH
    echo "nameserver 8.8.4.4" >> $DNS_PATH

    green_msg "DNS Fixed Temporarily."
    echo
    sleep 0.5
}

sudo apt -y install apt-transport-https locales apt-utils bash-completion libssl-dev socat

    sudo apt -y -q autoclean
    sudo apt -y clean
    sudo apt -q update
    sudo apt -y upgrade
    sudo apt -y autoremove --purge

optimize_tcp() {
    echo -e "${cran}Optimizing TCP settings for better performance...${NC}"

    # Backup current sysctl settings
    sudo cp /etc/sysctl.conf /etc/sysctl.conf.backup

    # Apply performance optimizations
    sudo bash -c 'cat <<EOF >> /etc/sysctl.conf
# TCP performance optimizations
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

# Additional optimizations
fs.file-max = 67108864
net.core.default_qdisc = fq_codel
net.core.netdev_max_backlog = 32768
net.core.optmem_max = 262144
net.core.somaxconn = 65536
net.core.rmem_max = 33554432
net.core.rmem_default = 1048576
net.core.wmem_max = 33554432
net.core.wmem_default = 1048576
net.ipv4.tcp_rmem = 16384 1048576 33554432
net.ipv4.tcp_wmem = 16384 1048576 33554432
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fin_timeout = 25
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_keepalive_probes = 7
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_max_orphans = 819200
net.ipv4.tcp_max_syn_backlog = 20480
net.ipv4.tcp_max_tw_buckets = 1440000
net.ipv4.tcp_mem = 65536 1048576 33554432
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_notsent_lowat = 32768
net.ipv4.tcp_retries2 = 8
net.ipv4.tcp_sack = 1
net.ipv4.tcp_dsack = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = -2
net.ipv4.tcp_ecn = 1
net.ipv4.tcp_ecn_fallback = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.udp_mem = 65536 1048576 33554432
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.lo.disable_ipv6 = 0
net.unix.max_dgram_qlen = 256
vm.min_free_kbytes = 65536
vm.swappiness = 10
vm.vfs_cache_pressure = 250
net.ipv4.conf.default.rp_filter = 2
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.neigh.default.gc_thresh1 = 512
net.ipv4.neigh.default.gc_thresh2 = 2048
net.ipv4.neigh.default.gc_thresh3 = 16384
net.ipv4.neigh.default.gc_stale_time = 60
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.lo.arp_announce = 2
net.ipv4.conf.all.arp_announce = 2
kernel.panic = 1
vm.dirty_ratio = 20
EOF'

    # Apply the new sysctl settings
    sudo sysctl -p

    echo -e "${Purple}TCP settings optimized.${NC}"
}

# Function to enable BBR
enable_bbr() {
    echo -e "${cran}Enabling BBR...${NC}"

    # Check if BBR is already enabled
    if lsmod | grep -q bbr; then
        echo -e "${Purple}BBR is already enabled.${NC}"
    else
        # Load the TCP BBR module
        sudo modprobe tcp_bbr

        # Ensure BBR is loaded on boot
        echo "tcp_bbr" | sudo tee -a /etc/modules-load.d/modules.conf

        # Set BBR as the default congestion control algorithm
        sudo bash -c 'echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf'
        sudo bash -c 'echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf'

        # Apply the new sysctl settings
        sudo sysctl -p

        echo -e "${cyan}BBR enabled.${NC}"
    fi
}

# Main function to perform all optimizations
optimize_network() {
    optimize_tcp
    enable_bbr
}

# Function to update system and install openssl
install_dependencies() {
    echo -e "${cyan}Updating package list...${NC}"
    sudo apt update -y

    echo -e "${cyan}Upgrading packages...${NC}"
    sudo apt upgrade -y

    echo -e "${cyan}Installing openssl...${NC}"
    sudo apt install -y openssl

    echo -e "${cyan}Installing jq...${NC}"
    sudo apt install -y jq

    echo "
                 
══════════════════════════════════════════════════════════════════════════════════════
        ____                             _     _                                     
    ,   /    )                           /|   /                                  /   
-------/____/---_--_----__---)__--_/_---/-| -/-----__--_/_-----------__---)__---/-__-
  /   /        / /  ) /   ) /   ) /    /  | /    /___) /   | /| /  /   ) /   ) /(    
_/___/________/_/__/_(___(_/_____(_ __/___|/____(___ _(_ __|/_|/__(___/_/_____/___\__

══════════════════════════════════════════════════════════════════════════════════════"

# Color codes
Purple='\033[0;35m'
Cyan='\033[0;36m'
cyan='\033[0;36m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
White='\033[0;96m'
RED='\033[0;31m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color 

# Function to show the menu
show_menu() {
    echo -e "${Purple}Please choose an option:${NC}"
    echo -e "${White}1. Reality Reverse Tunnel${NC}"
    echo -e "${Cyan}2. Reality Direct Tunnel${NC}"
    echo -e "${White}3. http2 , mux , grpc${NC}"
    echo -e "${Cyan}4. HalfDuplex Tunnel or Direct${NC}"
    echo -e "${White}5.  Optimize the Network settings${NC}"
    echo -e "${Cyan}9. Exit"
}

# Loop until the user chooses to exit
while true; do
    show_menu
    read -p "Enter choice [1-6]: " choice
    case $choice in
        1)
            clear
            bash <(curl https://raw.githubusercontent.com/ipmartnetwork/iPmart/main/reverse.sh)
            ;;
        2)
            clear
            bash <(curl https://raw.githubusercontent.com/ipmartnetwork/iPmart/main/direct.sh)
            ;;
        3)
            clear
            bash <(curl https://raw.githubusercontent.com/ipmartnetwork/iPmart/main/mux.sh)
            ;;
        4)
            clear
            bash <(curl https://raw.githubusercontent.com/ipmartnetwork/iPmart/main/halfduplex.sh)
            ;;

        5)
            clear
            optimize_network;;

        0)
            echo "Exit.."
            break
            ;;
        *)
            echo "Invalid choice! Please select a valid option."
            ;;
    esac
done
