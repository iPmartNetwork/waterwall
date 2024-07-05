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

cur_dir=$(pwd)
# check root
[[ $EUID -ne 0 ]] && echo -e "${RED}Fatal error: ${plain} Please run this script with root privilege \n " && exit 1

install_jq() {
    if ! command -v jq &> /dev/null; then
        # Check if the system is using apt package manager
        if command -v apt-get &> /dev/null; then
            echo -e "${RED}jq is not installed. Installing...${NC}"
            sleep 1
            sudo apt-get update
            sudo apt-get install -y jq
        else
            echo -e "${RED}Error: Unsupported package manager. Please install jq manually.${NC}\n"
            read -p "Press any key to continue..."
            exit 1
        fi
    fi
}


loader(){

    install_jq

    # Get server IP
    SERVER_IP=$(hostname -I | awk '{print $1}')

    # Fetch server country using ip-api.com
    SERVER_COUNTRY=$(curl -sS "http://ip-api.com/json/$SERVER_IP" | jq -r '.country')

    # Fetch server isp using ip-api.com 
    SERVER_ISP=$(curl -sS "http://ip-api.com/json/$SERVER_IP" | jq -r '.isp')

    WATER_CORE=$(check_core_status)
    WATER_TUNNEL=$(check_tunnel_status)

    init

}

init(){

    #clear page .
    clear
    echo  "
══════════════════════════════════════════════════════════════════════════════════════
        ____                             _     _                                     
    ,   /    )                           /|   /                                  /   
-------/____/---_--_----__---)__--_/_---/-| -/-----__--_/_-----------__---)__---/-__-
  /   /        / /  ) /   ) /   ) /    /  | /    /___) /   | /| /  /   ) /   ) /(    
_/___/________/_/__/_(___(_/_____(_ __/___|/____(___ _(_ __|/_|/__(___/_/_____/___\__

══════════════════════════════════════════════════════════════════════════════════════"                                                                                                        
    echo -e "|${GREEN}Server Country    |${NC} $SERVER_COUNTRY"
    echo -e "|${GREEN}Server IP         |${NC} $SERVER_IP"
    echo -e "|${GREEN}Server ISP        |${NC} $SERVER_ISP"
    echo -e "|${GREEN}WaterWall CORE    |${NC} $WATER_CORE"
    echo -e "|${GREEN}WaterWall Tunnel  |${NC} $WATER_TUNNEL"
    echo "+--------------------------------------------------------------------------------------------------------------+"
    echo -e "|${YELLOW}Please choose an option:${NC}"
    echo "+--------------------------------------------------------------------------------------------------------------+"
    echo -e "${YELLOW}| 1  - INSTALL CORE ${NC}"
    echo -e "${YELLOW}| 2  - Config Tunnel ${NC}"
    echo -e "${YELLOW}| 3  - Unistall ${NC}"
    echo -e "${YELLOW}| 0  - Exit ${NC}"
    echo "+--------------------------------------------------------------------------------------------------------------+"
    echo -e "\033[0m"

    read -p "Enter option number: " choice
    case $choice in
    1)
        install_core
        ;;  
    2)
        config_tunnel
        ;;
    3)
        unistall
        ;;
    0)
        echo -e "${GREEN}Exiting program...${NC}"
        exit 0
        ;;
    *)
        echo "Not valid"
        ;;
    esac
        

}

install_core(){

wget https://github.com/radkesvat/WaterWall/releases/download/v1.21/Waterwall-linux-64.zip
apt install unzip && unzip Waterwall-linux-64.zip
chmod +rwx Waterwall
    
cat <<EOL > core.json
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
            "iran.json"
        ]
    }
EOL

    echo 'WaterWall Core installed :)'
    echo $'\e[32minstalling WaterWall in 3 seconds... \e[0m' && sleep 1 && echo $'\e[32m2... \e[0m' && sleep 1 && echo $'\e[32m1... \e[0m' && sleep 1 && {
        clear
        init
    }

}

config_tunnel(){

        clear
                                                                                                       
        echo -e "|${GREEN}Server Country    |${NC} $SERVER_COUNTRY"
        echo -e "|${GREEN}Server IP         |${NC} $SERVER_IP"
        echo -e "|${GREEN}Server ISP        |${NC} $SERVER_ISP"
        echo -e "|${GREEN}WaterWall CORE    |${NC} $WATER_CORE"
        echo -e "|${GREEN}WaterWall Tunnel  |${NC} $WATER_TUNNEL"
        echo "+--------------------------------------------------------------------------------------------------------------+"
        echo -e "${GREEN}Please choose an option:${NC}"
        echo "+---------------------------------------------------------------+"
        echo -e "${BLUE}| 1  - IRAN"
        echo -e "${BLUE}| 2  - Kharej"
        echo -e "${BLUE}| 0  - Exit"
        echo "+---------------------------------------------------------------+"
        echo -e "\033[0m"

        read -p "Enter option number: " setup
        case $setup in
        1)

            read -p "Enter SNI : " clear_sni
            read -p "Enter Kharej IP : " kharej_ip

cat <<EOL > dev-ir.json
{
    "name": "reverse_reality_grpc_hd_multiport_server",
    "nodes": [
        {
            "name": "users_inbound",
            "type": "TcpListener",
            "settings": {
                "address": "0.0.0.0",
                "port": [23,65535],
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
            "name": "pbserver",
            "type": "ProtoBufServer",
            "settings": {},
            "next": "reverse_server"
        },
        {
            "name": "h2server",
            "type": "Http2Server",
            "settings": {},
            "next": "pbserver"
        },
        {
            "name": "halfs",
            "type": "HalfDuplexServer",
            "settings": {},
            "next": "h2server"
        },
        {
            "name": "reality_server",
            "type": "RealityServer",
            "settings": {
                "destination": "reality_dest",
                "password": "passwd"
            },
            "next": "halfs"
        },
        {
            "name": "kharej_inbound",
            "type": "TcpListener",
            "settings": {
                "address": "0.0.0.0",
                "port": 443,
                "nodelay": true,
                "whitelist": [
                    "$kharej_ip/32"
                ]
            },
            "next": "reality_server"
        },
        {
            "name": "reality_dest",
            "type": "TcpConnector",
            "settings": {
                "nodelay": true,
                "address": "$clear_sni",
                "port": 443
            }
        }
    ]
}
EOL
            run_screen
            echo $'\e[32mTunnel WaterWall in 3 seconds... \e[0m' && sleep 1 && echo $'\e[32m2... \e[0m' && sleep 1 && echo $'\e[32m1... \e[0m' && sleep 1 && {
                clear
                init
            }
            ;;
        2)

            read -p "Enter SNI : " clear_sni
            read -p "Enter IRAN IP : " iran_ip



cat <<EOL > iran.json
{
    "name": "reverse_reality_grpc_client_hd_multiport_client",
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
            "next": "pbclient"
        },
        {
            "name": "pbclient",
            "type": "ProtoBufClient",
            "settings": {},
            "next": "h2client"
        },
        {
            "name": "h2client",
            "type": "Http2Client",
            "settings": {
                "host": "$clear_sni",
                "port": 443,
                "path": "/",
                "content-type": "application/grpc",
                "concurrency": 64
            },
            "next": "halfc"
        },
        {
            "name": "halfc",
            "type": "HalfDuplexClient",
            "next": "reality_client"
        },
        
        {
            "name": "reality_client",
            "type": "RealityClient",
            "settings": {
                "sni": "$clear_sni",
                "password": "passwd"
            },
            "next": "outbound_to_iran"
        },
        {
            "name": "outbound_to_iran",
            "type": "TcpConnector",
            "settings": {
                "nodelay": true,
                "address": "$iran_ip",
                "port": 443
            }
        }
    ]
}
EOL

            run_screen
            echo $'\e[32mTunnel WaterWall in 3 seconds... \e[0m' && sleep 1 && echo $'\e[32m2... \e[0m' && sleep 1 && echo $'\e[32m1... \e[0m' && sleep 1 && {
                clear
                init
            }

            ;;
        0)
            echo -e "${GREEN}Exiting program...${NC}"
            exit 0
            ;;
        *)
            echo "Not valid"
            ;;
        esac
        

}

unistall(){

    echo $'\e[32mUninstalling WaterWall in 3 seconds... \e[0m' && sleep 1 && echo $'\e[32m2... \e[0m' && sleep 1 && echo $'\e[32m1... \e[0m' && sleep 1 && {
    rm Waterwall-linux-64.zip
    rm Waterwall-linux-64.zip*
    rm Waterwall
    rm dev-ir.json
    rm core.json
    clear
    echo 'WaterWall Unistalled :(';
    }


    loader
}

run_screen(){
#!/bin/bash

# Check if screen is installed
if ! command -v screen &> /dev/null
then
    echo "Screen is not installed. Installing..."
    
    # Check the Linux distribution to use the correct package manager
    if [ -f /etc/redhat-release ]; then
        # CentOS/RHEL
        sudo yum install screen -y
    elif [ -f /etc/debian_version ]; then
        # Debian/Ubuntu
        sudo apt-get update
        sudo apt-get install screen -y
    else
        echo "Unsupported Linux distribution. Please install screen manually."
        exit 1
    fi
    
    # Verify installation
    if ! command -v screen &> /dev/null
    then
        echo "Failed to install screen. Please install manually."
        exit 1
    else
        echo "Screen has been successfully installed."
    fi
else
    echo "Screen is already installed."
fi

# Run WaterWall in a new detached screen session
# screen -d -m -S WaterWall /path/to/WaterWall
# screen -S ipmart ./Waterwall
screen -dmS WaterWal /root/Waterwall

echo "WaterWall has been started in a new screen session."

}


check_core_status() {
    local file_path="core.json"
    local status

    if [ -f "$file_path" ]; then
        status="${GREEN}Installed"${NC}
    else
        status=${RED}"Not installed"${NC}
    fi

    echo "$status"
}

check_tunnel_status() {
    local file_path="iran.json"
    local status

    if [ -f "$file_path" ]; then
        status="${GREEN}Enabled"${NC}
    else
        status=${RED}"Disabled"${NC}
    fi

    echo "$status"
}

loader
