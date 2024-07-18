#!/bin/bash

clear
echo  "
══════════════════════════════════════════════════════════════════════════════════════
        ____                             _     _                                     
    ,   /    )                           /|   /                                  /   
-------/____/---_--_----__---)__--_/_---/-| -/-----__--_/_-----------__---)__---/-__-
  /   /        / /  ) /   ) /   ) /    /  | /    /___) /   | /| /  /   ) /   ) /(    
_/___/________/_/__/_(___(_/_____(_ __/___|/____(___ _(_ __|/_|/__(___/_/_____/___\__

══════════════════════════════════════════════════════════════════════════════════════"

# Coler Code
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
    echo -e "${White}5. reverse reality grpc hd${NC}"
    echo -e "${Cyan}6. reverse tls${NC}"
    echo -e "${White}7. Bgp4${NC}"
    echo -e "${Cyan}0. Exit${NC}"
}

# Loop until the user chooses to exit
while true; do
    show_menu
    read -p "Enter choice [1-0]: " choice
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
            bash <(curl https://raw.githubusercontent.com/ipmartnetwork/iPmart/main/iPmart.sh)
            ;;
        6)
            clear
            bash <(curl https://raw.githubusercontent.com/ipmartnetwork/iPmart/main/tls.sh)
            ;;
        7)
            clear
            bash <(curl https://raw.githubusercontent.com/ipmartnetwork/iPmart/main/Bgp4.sh)
            ;;          
        0)
            echo "Exit"
            break
            ;;
        *)
            echo "Invalid choice! Please select a valid option."
            ;;
    esac
done
