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
purple='\033[0;35m'
Cyan='\033[0;36m'
cyan='\033[0;36m'
CYAN='\033[0;36m'
White='\033[0;33m'
White='\033[0;96m'
RED='\033[0;31m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color
rest='\033[0m'

# Detect the Linux distribution
detect_distribution() {
	if [ -f /etc/os-release ]; then
		source /etc/os-release
		case "${ID}" in
		ubuntu | debian)
			p_m="apt-get"
			;;
		centos)
			p_m="yum"
			;;
		fedora)
			p_m="dnf"
			;;
		*)
			echo -e "${red}Unsupported distribution!${rest}"
			exit 1
			;;
		esac
	else
		echo -e "${red}Unsupported distribution!${rest}"
		exit 1
	fi
}

# Install Dependencies
check_dependencies() {
	detect_distribution

	local dependencies
	dependencies=("wget" "unzip" "socat" "jq")

	for dep in "${dependencies[@]}"; do
		if ! command -v "${dep}" &>/dev/null; then
			echo -e "${cyan} ${dep} ${White}is not installed. Installing...${rest}"
			sudo "${p_m}" install "${dep}" -y
		fi
	done
}

# Check and nstall waterwall
install_waterwall() {
	INSTALL_DIR="/root/Waterwall"
	FILE_NAME="Waterwall"

	if [ ! -f "$INSTALL_DIR/$FILE_NAME" ]; then
		check_dependencies

		echo -e "${cyan}Installing Waterwall...${rest}"

		# Determine the download URL based on the architecture
		ARCH=$(uname -m)
		if [ "$ARCH" == "x86_64" ]; then
			DOWNLOAD_URL="https://github.com/radkesvat/WaterWall/releases/download/v1.25/Waterwall-linux-64.zip"
		elif [ "$ARCH" == "aarch64" ]; then
			DOWNLOAD_URL="https://github.com/radkesvat/WaterWall/releases/download/v1.25/Waterwall-linux-arm64.zip"
		else
			echo -e "${red}Unsupported architecture: $ARCH${rest}"
			return 1
		fi

		# Create the installation directory if it doesn't exist
		mkdir -p "$INSTALL_DIR"

		# Download the ZIP file directly into INSTALL_DIR
		ZIP_FILE="$INSTALL_DIR/Waterwall.zip"
		curl -L -o "$ZIP_FILE" "$DOWNLOAD_URL"
		if [ $? -ne 0 ]; then
			echo -e "${red}Download failed.${rest}"
			return 1
		fi

		# Unzip the downloaded file directly into INSTALL_DIR
		unzip "$ZIP_FILE" -d "$INSTALL_DIR" >/dev/null 2>&1
		if [ $? -ne 0 ]; then
			echo -e "${red}Unzip failed.${rest}"
			rm -f "$ZIP_FILE"
			return 1
		fi

		rm -f "$ZIP_FILE"

		# Set executable permission for Waterwall binary
		sudo chmod +x "$INSTALL_DIR/$FILE_NAME"
		if [ $? -ne 0 ]; then
			echo -e "${red}Failed to set executable permission for Waterwall.${rest}"
			return 1
		fi

		echo -e "${purple}Waterwall installed successfully in $INSTALL_DIR.${rest}"
		echo -e "${cyan}============================${rest}"
		return 0
	fi
}

#===================================

#9
# SSL CERTIFICATE
install_acme() {
	cd ~
	echo -e "${purple}install acme...${rest}"

	curl https://get.acme.sh | sh
	if [ $? -ne 0 ]; then
		echo -e "${red}install acme failed${rest}"
		return 1
	else
		echo -e "${purple}install acme succeed${rest}"
	fi

	return 0
}

# SSL Menu
ssl_cert_issue_main() {
	echo -e "${White}      ===================================${rest}"
	echo -e "${White}      ${purple} 1.${purple} Get SSL Certificate${White} ${rest}"
	echo -e "${White}      ${purple} 2.${purple} Revoke${White}              ${rest}"
	echo -e "${White}      ${purple} 3.${purple} Force Renew${White}         ${rest}"
	echo -e "${White}      ${blue}===================================${White}${rest}"
	echo -e "${White}      ${purple} 0.${purple} Back to Main Menu${White}  ${rest}"
	echo -e "${White}      ===================================${rest}"
	echo -en "${cyan}      Enter your choice (1-3): ${rest}"
	read -r choice
	case "$choice" in
	0)
		main
		;;
	1)
		ssl_cert_issue
		;;
	2)
		local domain=""
		echo -e "${cyan}============================================${rest}"
		echo -en "${purple}Please enter your domain name to revoke the certificate: ${rest}"
		read -r domain
		~/.acme.sh/acme.sh --revoke -d "${domain}"
		if [ $? -ne 0 ]; then
			echo -e "${cyan}============================================${rest}"
			echo -e "${red}Failed to revoke certificate. Please check logs.${rest}"
		else
			echo -e "${cyan}============================================${rest}"
			echo -e "${purple}Certificate revoked${rest}"
		fi
		;;
	3)
		local domain=""
		echo -e "${cyan}============================================${rest}"
		echo -en "${purple}Please enter your domain name to forcefully renew an SSL certificate: ${rest}"
		read -r domain
		~/.acme.sh/acme.sh --renew -d "${domain}" --force
		if [ $? -ne 0 ]; then
			echo -e "${cyan}============================================${rest}"
			echo -e "${red}Failed to renew certificate. Please check logs.${rest}"
		else
			echo -e "${cyan}============================================${rest}"
			echo -e "${purple}Certificate renewed${rest}"
		fi
		;;
	*) echo -e "${red}Invalid choice${rest}" ;;
	esac
}

ssl_cert_issue() {
	echo -e "${cyan}============================================${rest}"
	release=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
	# check for acme.sh first
	if [ ! -f ~/.acme.sh/acme.sh ]; then
		echo -e "${purple}acme.sh could not be found. we will install it${rest}"
		install_acme
		if [ $? -ne 0 ]; then
			echo -e "${red}install acme failed, please check logs${rest}"
			exit 1
		fi
	fi

	# install socat second
	case "${release}" in
	ubuntu | debian | armbian)
		apt update -y
		;;
	centos | almalinux | rocky | oracle)
		yum -y update
		;;
	fedora)
		dnf -y update
		;;
	arch | manjaro | parch)
		pacman -Sy --noconfirm socat
		;;
	*)
		echo -e "${red}Unsupported operating system. Please check the script and install the necessary packages manually.${rest}\n"
		exit 1
		;;
	esac
	if [ $? -ne 0 ]; then
		echo -e "${red}install socat failed, please check logs${rest}"
		exit 1
	else
		echo -e "${cyan}============================${rest}"
	fi

	# get the domain here,and we need verify it
	local domain=""
	echo -en "${purple}Please enter your domain name: ${rest}"
	read -r domain
	echo -e "${purple}Your domain is:${White}${domain}${purple},check it...${rest}"

	# check if there already exists a cert
	local currentCert
	currentCert=$(~/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}')

	if [ "${currentCert}" == "${domain}" ]; then
		local certInfo
		certInfo=$(~/.acme.sh/acme.sh --list)
		echo -e "${red}system already has certs here,can not issue again,Current certs details:${rest}"
		echo -e "${purple} $certInfo${rest}"
		exit 1
	else
		echo -e "${purple} your domain is ready for issuing cert now...${rest}"
	fi

	# create a directory for install cert
	certPath="/root/Waterwall/cert"
	if [ ! -d "$certPath" ]; then
		mkdir -p "$certPath"
	else
		rm -rf "$certPath"
		mkdir -p "$certPath"
	fi

	# get needed port here
	echo -en "${purple}please choose which port do you use,default will be 80 port:${rest}"
	read -r WebPort
	WebPort=${WebPort:-80}
	if [[ ${WebPort} -gt 65535 || ${WebPort} -lt 1 ]]; then
		echo -e "${red}your input ${WebPort} is invalid,will use default port${rest}"
		WebPort=80
	fi
	echo -e "${purple} will use port:${WebPort} to issue certs,please make sure this port is open...${rest}"
	# issue the cert
	~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
	~/.acme.sh/acme.sh --issue -d "${domain}" --listen-v6 --standalone --httpport "${WebPort}"
	if [ $? -ne 0 ]; then
		echo -e "${red}issue certs failed,please check logs${rest}"
		rm -rf ~/.acme.sh/"${domain}"
		exit 1
	else
		echo -e "${White}issue certs succeed,installing certs...${rest}"
	fi
	# install cert
	~/.acme.sh/acme.sh --installcert -d "${domain}" \
		--key-file /root/Waterwall/cert/privkey.pem \
		--fullchain-file /root/Waterwall/cert/fullchain.pem

	if [ $? -ne 0 ]; then
		echo -e "${red}install certs failed,exit${rest}"
		rm -rf ~/.acme.sh/"${domain}"
		exit 1
	else
		echo -e "${purple} install certs succeed,enable auto renew...${rest}"
	fi

	~/.acme.sh/acme.sh --upgrade --auto-upgrade
	if [ $? -ne 0 ]; then
		echo -e "${red}auto renew failed, certs details:${rest}"
		ls -lah "$certPath"/*
		chmod 755 "$certPath"/*
		exit 1
	else
		echo -e "${purple} auto renew succeed, certs details:${rest}"
		ls -lah "$certPath"/*
		chmod 755 "$certPath"/*
	fi

	sudo systemctl restart trojan.service >/dev/null 2>&1
	sudo systemctl restart Waterwall.service >/dev/null 2>&1
}
#===================================

#00
# Core.json
create_core_json() {
	if [ ! -d /root/Waterwall ]; then
		mkdir -p /root/Waterwall
	fi

	if [ ! -f ~/Waterwall/core.json ]; then
		echo -e "${cyan}Creating core.json...${rest}"
		echo ""
		cat <<EOF >~/Waterwall/core.json
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
	fi
}

#===================================

#0
# Trojan Core.json
create_trojan_core_json() {
	if [ ! -d /root/Waterwall/trojan ]; then
		mkdir -p /root/Waterwall/trojan
	fi

	if [ ! -f ~/Waterwall/trojan/core.json ]; then
		echo -e "${cyan}Creating core.json...${rest}"
		echo ""
		cat <<EOF >~/Waterwall/trojan/core.json
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
        "trojan_config.json"
    ]
}
EOF
	fi
}

#===================================

#2
# Tls Tunnel
tls() {
	# Function to create tls port to port iran
	create_tls_port_to_port_iran() {
		echo -e "${cyan}════════════════════════════════════════════${rest}"
		echo -en "${purple}Enter Your Domain:${rest} "
		read -r domain
		echo -en "${purple}Enter the local port: ${rest}"
		read -r local_port
		echo -en "${purple}Enter the remote address: ${rest}"
		read -r remote_address
		echo -en "${purple}Enter the remote port: ${rest}"
		read -r remote_port
		echo -en "${purple}Do you want to Enable Http2 ? (yes/no) [default: yes] : ${rest}"
		read -r http2
		http2=${http2:-yes}
		if [ "$http2" == "yes" ]; then
			echo -en "${purple}Enter the Connection port: ${rest}"
			read -r connection_port
		else
			echo -en "${purple}Do you want to Enable PreConnect ? (yes/no) [default: yes]: ${rest}"
			read -r PreConnect
			PreConnect=${PreConnect:-yes}
			echo -e "${cyan}════════════════════════════════════════════${rest}"
		fi

		if [ "$http2" == "no" ] && [ "$PreConnect" == "no" ]; then
			output="sslclient"
		elif [ "$http2" == "no" ] && [ "$PreConnect" == "yes" ]; then
			output="precon_client"
		else
			output="pbclient"
		fi

		install_waterwall

		json=$(
			cat <<EOF
{
    "name": "tls_port_to_port_iran",
    "nodes": [
        {
            "name": "input",
            "type": "TcpListener",
            "settings": {
                "address": "0.0.0.0",
                "port": $local_port,
                "nodelay": true
            },
            "next": "$output"
        },
EOF
		)

		if [ "$http2" == "yes" ]; then
			json+=$(
				cat <<EOF

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
                "host": "$domain",
                "port": $connection_port,
                "path": "/",
                "content-type": "application/grpc"
            },
            "next": "sslclient"
        },
EOF
			)
		else
			if [ "$PreConnect" == "yes" ]; then
				json+=$(
					cat <<EOF

        {
            "name": "precon_client",
            "type": "PreConnectClient",
            "settings": {
                "minimum-unused": 1
            },
            "next": "sslclient"
        },
EOF
				)
			fi
		fi

		if [ "$http2" == "yes" ]; then
			alpn="h2"
		else
			alpn="http/1.1"
		fi

		json+=$(
			cat <<EOF
		
        {
            "name": "sslclient",
            "type": "OpenSSLClient",
            "settings": {
                "sni": "$domain",
                "verify": true,
                "alpn": "$alpn"
            },
            "next": "output"
        },
        {
            "name": "output",
            "type": "TcpConnector",
            "settings": {
                "nodelay": true,
                "address": "$remote_address",
                "port": $remote_port
            }
        }
    ]
}
EOF
		)
		echo "$json" >/root/Waterwall/config.json
	}

	# Function to create tls port to port config
	create_tls_port_to_port_kharej() {
		echo -e "${cyan}════════════════════════════════════════════${rest}"
		echo -en "${purple}Enter Your Domain: ${rest}"
		read -r domain
		echo -en "${purple}Enter the local port: ${rest}"
		read -r local_port
		echo -en "${purple}Enter the remote port: ${rest}"
		read -r remote_port
		echo -en "${purple}Do you want to Enable Http2 ? (yes/no) [default: yes] : ${rest}"
		read -r http2
		http2=${http2:-yes}
		if [ "$http2" == "yes" ]; then
			echo -en "${purple}Enter the Connection port: ${rest}"
			read -r connection_port
		fi

		if [ "$http2" == "yes" ]; then
			output="pbserver"
		else
			output="output"
		fi

		install_waterwall

		json=$(
			cat <<EOF
{
    "name": "tls_port_to_port_kharej",
    "nodes": [
        {
            "name": "input",
            "type": "TcpListener",
            "settings": {
                "address": "0.0.0.0",
                "port": $local_port,
                "nodelay": true
            },
            "next": "sslserver"
        },
        {
            "name": "sslserver",
            "type": "OpenSSLServer",
            "settings": {
                "cert-file": "/root/Waterwall/cert/fullchain.pem",
                "key-file": "/root/Waterwall/cert/privkey.pem",
                "alpns": [
                    {
                        "value": "h2",
                        "next": "node->next"
                    },
                    {
                        "value": "http/1.1",
                        "next": "node->next"
                    }
                ]
            },
            "next": "$output"  
        },
EOF
		)

		if [ "$http2" == "yes" ]; then
			json+=$(
				cat <<EOF

        {
            "name": "pbserver",
            "type": "ProtoBufServer",
            "settings": {},
            "next": "h2server"
        },
        {
            "name": "h2server",
            "type": "Http2Server",
            "settings": {},
            "next": "output"
        },
EOF
			)
		fi

		json+=$(
			cat <<EOF
		
        {
            "name": "output",
            "type": "Connector",
            "settings": {
                "nodelay": true,
                "address": "127.0.0.1",
                "port": $remote_port
            }
        }
    ]
}
EOF
		)
		echo "$json" >/root/Waterwall/config.json
		echo -e "${White}You should get [SSL CERTIFICATE] for your domain in main Menu${rest}"
	}

	# Function to create tls multi port iran
	create_tls_multi_port_iran() {
		echo -e "${cyan}════════════════════════════════════════════${rest}"
		echo -en "${purple}Enter Your Domain: ${rest}"
		read -r domain
		echo -en "${purple}Enter the starting local port (greater than 23): ${rest}"
		read -r start_port
		echo -en "${purple}Enter the ending local port (less than 65535): ${rest}"
		read -r end_port
		echo -en "${purple}Enter the remote address: ${rest}"
		read -r remote_address
		echo -en "${purple}Enter the remote port: ${rest}"
		read -r remote_port
		echo -en "${purple}Do you want to Enable Http2 ? (yes/no) [default: yes] : ${rest}"
		read -r http2
		http2=${http2:-yes}
		if [ "$http2" == "yes" ]; then
			echo -en "${purple}Enter the Connection port: ${rest}"
			read -r connection_port
		else
			echo -en "${purple}Do you want to Enable PreConnect ? (yes/no) [default: yes]: ${rest}"
			read -r PreConnect
			PreConnect=${PreConnect:-yes}
			echo -e "${cyan}════════════════════════════════════════════${rest}"
		fi

		if [ "$http2" == "no" ] && [ "$PreConnect" == "no" ]; then
			output="sslclient"
		elif [ "$http2" == "no" ] && [ "$PreConnect" == "yes" ]; then
			output="precon_client"
		else
			output="pbclient"
		fi

		install_waterwall

		json=$(
			cat <<EOF
{
    "name": "tls_multiport_iran",
    "nodes": [
        {
            "name": "input",
            "type": "TcpListener",
            "settings": {
                "address": "0.0.0.0",
                "port": [23,65535],
                "nodelay": true
            },
            "next": "port_header"
        },
        {
            "name": "port_header",
            "type": "HeaderClient",
            "settings": {
                "data": "src_context->port"
            },
            "next": "$output"
        },
EOF
		)

		# Check Http2
		if [ "$http2" == "yes" ]; then
			json+=$(
				cat <<EOF

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
                "host": "$domain",
                "port": $connection_port,
                "path": "/",
                "content-type": "application/grpc"
            },
            "next": "sslclient"
        },
EOF
			)
		else
			if [ "$PreConnect" == "yes" ]; then
				json+=$(
					cat <<EOF

        {
            "name": "precon_client",
            "type": "PreConnectClient",
            "settings": {
                "minimum-unused": 1
            },
            "next": "sslclient"
        },
EOF
				)
			fi
		fi

		json+=$(
			cat <<EOF

        {
            "name": "sslclient",
            "type": "OpenSSLClient",
            "settings": {
                "sni": "$domain",
                "verify": true,
                "alpn":"http/1.1"
            },
            "next": "output"
        },
        {
            "name": "output",
            "type": "TcpConnector",
            "settings": {
                "nodelay": true,
                "address": "$remote_address",
                "port": $remote_port
            }
        }
    ]
}
EOF
		)
		echo "$json" >/root/Waterwall/config.json
	}

	# Function to create tls multi port kharej
	create_tls_multi_port_kharej() {
		echo -e "${cyan}════════════════════════════════════════════${rest}"
		echo -en "${purple}Enter the local port: ${rest}"
		read -r local_port
		echo -en "${purple}Do you want to Enable Http2 ? (yes/no) [default: yes] : ${rest}"
		read -r http2
		http2=${http2:-yes}

		if [ "$http2" == "yes" ]; then
			output="pbserver"
		else
			output="output"
		fi

		install_waterwall

		json=$(
			cat <<EOF
{
    "name": "tls_multiport_kharej",
    "nodes": [
        {
            "name": "input",
            "type": "TcpListener",
            "settings": {
                "address": "0.0.0.0",
                "port": $local_port,
                "nodelay": true
            },
            "next": "sslserver"
        },
        {
            "name": "sslserver",
            "type": "OpenSSLServer",
            "settings": {
                "cert-file": "/root/Waterwall/cert/fullchain.pem",
                "key-file": "/root/Waterwall/cert/privkey.pem",
                "alpns": [
                    {
                        "value": "h2",
                        "next": "node->next"
                    },
                    {
                        "value": "http/1.1",
                        "next": "node->next"
                    }
                ],
                "fallback-intence-delay":0
            },
            "next": "port_header"
        },
        {
            "name":"port_header",
            "type": "HeaderServer",
            "settings": {
                "override": "dest_context->port"
            },
            "next": "$output"
        },
EOF
		)

		if [ "$http2" == "yes" ]; then
			json+=$(
				cat <<EOF

        {
            "name": "pbserver",
            "type": "ProtoBufServer",
            "settings": {},
            "next": "h2server"
        },
        {
            "name": "h2server",
            "type": "Http2Server",
            "settings": {},
            "next": "output"
        },
EOF
			)
		fi

		json+=$(
			cat <<EOF

        {
            "name": "output",
            "type": "TcpConnector",
            "settings": {
                "nodelay": true,
                "address":"127.0.0.1",
                "port":"dest_context->port"
            }
        }
    ]
}
EOF
		)
		echo "$json" >/root/Waterwall/config.json
		echo -e "${White}You should get [SSL CERTIFICATE] for your domain in main Menu${rest}"
	}

	echo -e "${White}  ${blue}════════════════════════════════════════════${White}${rest}"
	echo -e "${White}  ${purple} 1.${purple} Tls Multiport iran${White}      ${rest}"
	echo -e "${White}  ${purple} 2.${purple} Tls Multiport kharej${White}    ${rest}"
	echo -e "${White}  ${blue}════════════════════════════════════════════${White}${rest}"
	echo -e "${White}  ${purple} [0]${purple} ${purple}Back to ${purple}Main Menu${White}      |${rest}"
	echo -e "${White}      ════════════════════════════════════════════${rest}"
	echo -en "${cyan}   Enter your choice (1-2): ${rest}"
	read -r choice

	case $choice in
	1)
		create_tls_port_to_port_iran
		waterwall_service
		;;
	2)
		create_tls_port_to_port_kharej
		waterwall_service
		;;
	3)
		create_tls_multi_port_iran
		waterwall_service
		;;
	4)
		create_tls_multi_port_kharej
		waterwall_service
		;;
	0)
		main
		;;
	*)
		echo -e "${red}Invalid choice!${rest}"
		;;
	esac
}

# Uninstall Waterwall
uninstall_waterwall() {
	if [ -f ~/Waterwall/config.json ] || [ -f /etc/systemd/system/Waterwall.service ]; then
	    echo -e "${cyan}════════════════════════════════════════════${rest}"
		echo -en "${purple}Press Enter to continue, or Ctrl+C to cancel.${rest}"
		read -r
		if [ -d ~/Waterwall/cert ] || [ -f ~/.acme/acme.sh ]; then
			echo -e "${cyan}════════════════════════════════════════════${rest}"
			echo -en "${purple}Do you want to delete the Domain Certificates? (yes/no): ${rest}"
			read -r delete_cert

			if [[ "$delete_cert" == "yes" ]]; then
				echo -e "${cyan}════════════════════════════════════════════${rest}"
				echo -en "${purple}Enter Your domain: ${rest}"
				read -r domain

				rm -rf ~/.acme.sh/"${domain}"_ecc
				rm -rf ~/Waterwall/cert
				echo -e "${purple}Certificate for ${domain} has been deleted.${rest}"
			fi
		fi

		rm -rf ~/Waterwall/{core.json,config.json,Waterwall,log/}
		systemctl stop Waterwall.service >/dev/null 2>&1
		systemctl disable Waterwall.service >/dev/null 2>&1
		rm -rf /etc/systemd/system/Waterwall.service >/dev/null 2>&1
		echo -e "${cyan}════════════════════════════════════════════${rest}"
		echo -e "${purple}Waterwall has been uninstalled successfully.${rest}"
		echo -e "${cyan}════════════════════════════════════════════${rest}"
	else
		echo -e "${cyan}════════════════════════════════════════════${rest}"
		echo -e "${red}Waterwall is not installed.${rest}"
		echo -e "${cyan}════════════════════════════════════════════${rest}"
	fi
}
#===================================

# Create Service
waterwall_service() {
	create_core_json
	# Create a new service
	cat <<EOL >/etc/systemd/system/Waterwall.service
[Unit]
Description=Waterwall Tunnel Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/Waterwall
ExecStart=/root/Waterwall/Waterwall
Restart=always
RestartSec=3s

[Install]
WantedBy=multi-user.target
EOL

	# Reload systemctl daemon and start the service
	sudo systemctl daemon-reload
	sudo systemctl restart Waterwall.service >/dev/null 2>&1
	check_waterwall_status
}
#===================================

# Trojan Service
trojan_service() {
	create_trojan_core_json
	# Create Trojan service
	cat <<EOL >/etc/systemd/system/trojan.service
[Unit]
Description=Waterwall Trojan Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/Waterwall/trojan
ExecStart=/root/Waterwall/Waterwall
Restart=always
RestartSec=3s

[Install]
WantedBy=multi-user.target
EOL

	# Reload systemctl daemon and start the service
	sudo systemctl daemon-reload
	sudo systemctl restart trojan.service >/dev/null 2>&1
}
#===================================
# Check Install service
check_install_service() {
	if [ -f /etc/systemd/system/Waterwall.service ]; then
		echo -e "${cyan}════════════════════════════════════════════${rest}"
		echo -e "${red}Please uninstall the existing Waterwall service before continuing.${rest}"
		echo -e "${cyan}════════════════════════════════════════════${rest}"
		exit 1
	fi
}
#===================================
# Check tunnel status
check_tunnel_status() {
	# Check the status of the tunnel service
	if sudo systemctl is-active --quiet Waterwall.service; then
		echo -e "${White}     Waterwall :${purple} [running ✔] ${rest}"
	fi
}
#===================================
# Check Waterwall status
check_waterwall_status() {
	sleep 1
	# Check the status of the tunnel service
	if sudo systemctl is-active --quiet Waterwall.service; then
		echo -e "${cyan}Waterwall Installed successfully :${purple} [running ✔] ${rest}"
		echo -e "${cyan}════════════════════════════════════════════${rest}"
	else
		echo -e "${White}Waterwall is not installed or ${red}[Not running ✗ ] ${rest}"
		echo -e "${cyan}════════════════════════════════════════════${rest}"
	fi
}

#===================================

# Main Menu
main() {

	echo ""
	check_tunnel_status
	echo -e " 1.${cyan} SSL Certificate Management${rest}"
	echo -e " 2.${cyan} Tls Tunnel${rest}"
	echo -e " 3.${cyan} Uninstall Waterwall${rest}"
	echo -e " 0.${cyan} Exit${rest}"

	echo -en "${cyan}Enter your choice (1-3): ${rest}"
	read -r choice

	case $choice in
	1)
		ssl_cert_issue_main
		;;
	2)
		check_install_service
		tls
		;;
	3)
		uninstall_waterwall
		;;
	0)
		echo -e "${cyan}Exit${rest}"
		exit
		;;
	*)
		echo -e "${red}Invalid choice!${rest}"
		;;
	esac
}
mai
