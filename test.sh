#!/bin/bash

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


cur_dir=$(pwd)
# check root
#[[ $EUID -ne 0 ]] && echo -e "${Purple}Fatal error: ${plain} Please run this script with root privilege \n " && exit 1

install_jq() {
    if ! command -v jq &> /dev/null; then
        # Check if the system is using apt package manager
        if command -v apt-get &> /dev/null; then
            echo -e "${Purple}jq is not installed. Installing...${NC}"
            sleep 1
            sudo apt-get update
            sudo apt-get install -y jq
        else
            echo -e "${Purple}Error: Unsupported package manager. Please install jq manually.${NC}\n"
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

    init

}

init(){

    #clear page .
    clear
    # Function to display ASCII logo
    echo -e "${Purple}"
    cat << "EOF"

══════════════════════════════════════════════════════════════════════════════════════
        ____                             _     _                                     
    ,   /    )                           /|   /                                  /   
-------/____/---_--_----__---)__--_/_---/-| -/-----__--_/_-----------__---)__---/-__-
  /   /        / /  ) /   ) /   ) /    /  | /    /___) /   | /| /  /   ) /   ) /(    
_/___/________/_/__/_(___(_/_____(_ __/___|/____(___ _(_ __|/_|/__(___/_/_____/___\__

══════════════════════════════════════════════════════════════════════════════════════
EOF
    echo -e "${NC}"
                                                                                                       
    echo -e "${cyan}Server Country:${NC} $SERVER_COUNTRY"
    echo -e "${cyan}Server IP:${NC} $SERVER_IP"
    echo -e "${cyan}Server ISP:${NC} $SERVER_ISP"
    echo "+---------------------------------------------------------------+"
    echo -e "${YELLOW}Please choose an option:${NC}"
    echo "+---------------------------------------------------------------+"
    echo -e "${cyan}| 1  - INSTALL CORE"
    echo -e "${White}| 2  - Config Tunnel "
    echo -e "${cyan}| 3  - Unistall"
    echo -e "${White}| 0  - Exit"
    echo "+---------------------------------------------------------------+"
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
        echo -e "${cyan}Exiting program...${NC}"
        exit 0
        ;;
    *)
        echo "Not valid"
        ;;
    esac
        

}

# Determine the architecture and set the ASSET_NAME accordingly
ARCH=$(uname -m)
if [ "$ARCH" == "aarch64" ]; then
  ASSET_NAME="Waterwall-linux-arm64.zip"
elif [ "$ARCH" == "x86_64" ]; then
  ASSET_NAME="Waterwall-linux-64.zip"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

# Function to download and unzip the release
download_and_unzip() {
  local url="$1"
  local dest="$2"

  echo "Downloading $dest from $url..."
  wget -q -O "$dest" "$url"
  if [ $? -ne 0 ]; then
    echo "Error: Unable to download file."
    return 1
  fi

  echo "Unzipping $dest..."
  unzip -o "$dest"
  if [ $? -ne 0 ]; then
    echo "Error: Unable to unzip file."
    return 1
  fi
  
  sleep 0.5
  chmod +x Waterwall
  rm "$dest"

  echo "Download and unzip completed successfully."
}

# Function to get download URL for the latest release
get_latest_release_url() {
  local api_url="https://api.github.com/repos/radkesvat/WaterWall/releases/latest"

  echo "Fetching latest release data..." >&2
  local response=$(curl -s "$api_url")
  if [ $? -ne 0 ]; then
    echo "Error: Unable to fetch release data." >&2
    return 1
  fi

  local asset_url=$(echo "$response" | jq -r ".assets[] | select(.name == \"$ASSET_NAME\") | .browser_download_url")
  if [ -z "$asset_url" ]; then
    echo "Error: Asset not found." >&2
    return 1
  fi

  echo "$asset_url"
}

# Function to get download URL for a specific release version
get_specific_release_url() {
  local version=$1
  local api_url="https://api.github.com/repos/radkesvat/WaterWall/releases/tags/$version"

  echo "Fetching release data for version $version..." >&2
  response=$(curl -s $api_url)
  if [ $? -ne 0 ]; then
    echo "Error: Unable to fetch release data for version $version." >&2
    exit 1
  fi

  local asset_url=$(echo $response | jq -r ".assets[] | select(.name == \"$ASSET_NAME\") | .browser_download_url")
  if [ -z "$asset_url" ]; then
    echo "Error: Asset not found for version $version." >&2
    exit 1
  fi

  echo $asset_url
}  
  
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
    echo $'\e[36mUninstalling WaterWall in 3 seconds... \e[0m' && sleep 1 && echo $'\e[32m2... \e[0m' && sleep 1 && echo $'\e[32m1... \e[0m' && sleep 1 && {
        clear
        init
    }

}

config_tunnel(){

        clear                                                                                                        
        echo -e "${cyan}Server Country:${NC} $SERVER_COUNTRY"
        echo -e "${cyan}Server IP:${NC} $SERVER_IP"
        echo -e "${cyan}Server ISP:${NC} $SERVER_ISP"
        echo "+---------------------------------------------------------------+"
        echo -e "${YELLOW}Please choose an option:${NC}"
        echo "+---------------------------------------------------------------+"
        echo -e "${cyan}| 1  - IRAN"
        echo -e "${Purple}| 2  - Kharej"
        echo -e "${cyan}| 0  - Exit"
        echo "+---------------------------------------------------------------+"
        echo -e "\033[0m"

        read -p "Enter option number: " setup
        case $setup in
        1)

            read -p "Enter SNI : " clear_sni
            read -p "Enter Kharej IP : " kharej_ip

cat <<EOL > iran.json
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
                "password": "220049AHS04"
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
            # nohup ./Waterwall &
            # ./run_screen.py
            run_screen
            echo "Tunnel is ready"
            clear

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
                "password": "220049AHS04"
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
            # nohup ./Waterwall &
            # ./run_screen.py
            run_screen
            echo "Tunnel is ready"
            clear

            ;;
        0)
            echo -e "${YELLOW}Exiting program...${NC}"
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
    rm iran.json
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
# screen -S iran ./Waterwall
screen -dmS WaterWal /root/Waterwall

echo "WaterWall has been started in a new screen session."

}

loader
