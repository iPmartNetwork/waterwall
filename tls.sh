#!/bin/bash

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
	dependencies=("wget" "curl" "unzip" "socat" "jq")

	for dep in "${dependencies[@]}"; do
		if ! command -v "${dep}" &>/dev/null; then
			echo -e "${cyan} ${dep} ${yellow}is not installed. Installing...${rest}"
			sudo "${p_m}" install "${dep}" -y
		fi
	done
}

# Check and nstall waterwall
install_waterwall() {
	LATEST_RELEASE=$(curl --silent "https://api.github.com/repos/radkesvat/WaterWall/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')
	INSTALL_DIR="/root/Waterwall"
	FILE_NAME="Waterwall"

	if [ ! -f "$INSTALL_DIR/$FILE_NAME" ]; then
		check_dependencies
		echo ""
		echo -e "${cyan}============================${rest}"
		echo -e "${cyan}Installing Waterwall...${rest}"

		if [ -z "$LATEST_RELEASE" ]; then
			echo -e "${red}Failed to get the latest release version.${rest}"
			return 1
			LATEST_RELEASE
		fi

		echo -e "${cyan}Latest version: ${yellow}${LATEST_RELEASE}${rest}"

		# Determine the download URL based on the architecture
		ARCH=$(uname -m)
		if [ "$ARCH" == "x86_64" ]; then
			DOWNLOAD_URL="https://github.com/radkesvat/WaterWall/releases/download/${LATEST_RELEASE}/Waterwall-linux-64.zip"
		elif [ "$ARCH" == "aarch64" ]; then
			DOWNLOAD_URL="https://github.com/radkesvat/WaterWall/releases/download/${LATEST_RELEASE}/Waterwall-linux-arm64.zip"
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

		echo -e "${green}Waterwall installed successfully in $INSTALL_DIR.${rest}"
		echo -e "${cyan}============================${rest}"
		return 0
	fi
}

#===================================

#9
# SSL CERTIFICATE
install_acme() {
	cd ~
	echo -e "${green}install acme...${rest}"

	curl https://get.acme.sh | sh
	if [ $? -ne 0 ]; then
		echo -e "${red}install acme failed${rest}"
		return 1
	else
		echo -e "${green}install acme succeed${rest}"
	fi

	return 0
}

# SSL Menu
ssl_cert_issue_main() {
	echo -e "1. ${cyan} Get SSL Certificate${rest}"
	echo -e "2. ${White} Revoke${rest}"
	echo -e "3. ${cyan} Force Renew${rest}"
	echo -e "0. ${White} Back to Main Menu${rest}"
	echo -en "${Purple} Enter your choice (1-3): ${rest}"
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
		echo -en "${green}Please enter your domain name to revoke the certificate: ${rest}"
		read -r domain
		~/.acme.sh/acme.sh --revoke -d "${domain}"
		if [ $? -ne 0 ]; then
			echo -e "${cyan}============================================${rest}"
			echo -e "${red}Failed to revoke certificate. Please check logs.${rest}"
		else
			echo -e "${cyan}============================================${rest}"
			echo -e "${green}Certificate revoked${rest}"
		fi
		;;
	3)
		local domain=""
		echo -e "${cyan}============================================${rest}"
		echo -en "${green}Please enter your domain name to forcefully renew an SSL certificate: ${rest}"
		read -r domain
		~/.acme.sh/acme.sh --renew -d "${domain}" --force
		if [ $? -ne 0 ]; then
			echo -e "${cyan}============================================${rest}"
			echo -e "${red}Failed to renew certificate. Please check logs.${rest}"
		else
			echo -e "${cyan}============================================${rest}"
			echo -e "${green}Certificate renewed${rest}"
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
		echo -e "${green}acme.sh could not be found. we will install it${rest}"
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
	echo -en "${green}Please enter your domain name: ${rest}"
	read -r domain
	echo -e "${green}Your domain is:${yellow}${domain}${green},check it...${rest}"

	# check if there already exists a cert
	local currentCert
	currentCert=$(~/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}')

	if [ "${currentCert}" == "${domain}" ]; then
		local certInfo
		certInfo=$(~/.acme.sh/acme.sh --list)
		echo -e "${red}system already has certs here,can not issue again,Current certs details:${rest}"
		echo -e "${green} $certInfo${rest}"
		exit 1
	else
		echo -e "${green} your domain is ready for issuing cert now...${rest}"
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
	echo -e "${cyan}============================================${rest}"
	echo -en "${green}Please choose which port you want to use [${yellow}Default: 80${green}]: ${rest}"
	read -r WebPort
	WebPort=${WebPort:-80}
	if [[ ${WebPort} -gt 65535 || ${WebPort} -lt 1 ]]; then
		echo -e "${red}your input ${WebPort} is invalid,will use default port${rest}"
		WebPort=80
	fi
	echo -e "${green} will use port:${WebPort} to issue certs,please make sure this port is open...${rest}"
	echo -e "${cyan}============================================${rest}"
	# issue the cert
	~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
	~/.acme.sh/acme.sh --issue -d "${domain}" --listen-v6 --standalone --httpport "${WebPort}"
	if [ $? -ne 0 ]; then
		echo -e "${red}issue certs failed,please check logs${rest}"
		rm -rf ~/.acme.sh/"${domain}"
		exit 1
	else
		echo -e "${yellow}issue certs succeed,installing certs...${rest}"
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
		echo -e "${green} install certs succeed,enable auto renew...${rest}"
	fi

	~/.acme.sh/acme.sh --upgrade --auto-upgrade
	if [ $? -ne 0 ]; then
		echo -e "${red}auto renew failed, certs details:${rest}"
		ls -lah "$certPath"/*
		chmod 755 "$certPath"/*
		exit 1
	else
		echo -e "${green} auto renew succeed, certs details:${rest}"
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

#2
# Tls Tunnel
tls() {
	# Function to create tls port to port iran
	create_tls_port_to_port_iran() {
		echo -e "${cyan}============================${rest}"
		echo -en "${green}Enter Your Domain:${rest} "
		read -r domain
		echo -en "${green}Enter the local (${yellow}Client Config${green}) port: ${rest}"
		read -r local_port
		echo -en "${green}Enter the remote address: ${rest}"
		read -r remote_address
		echo -en "${green}Enter the remote (${yellow}Connection${green}) port: ${rest}"
		read -r remote_port
		echo -en "${green}Do you want to Enable Http2 ? (yes/no) [${yellow}Default: yes${green}] : ${rest}"
		read -r http2
		http2=${http2:-yes}
		if [ "$http2" == "no" ]; then
			echo -en "${green}Do you want to Enable PreConnect ? (yes/no) [${yellow}Default: yes${green}]: ${rest}"
			read -r PreConnect
			PreConnect=${PreConnect:-yes}
			if [ "$PreConnect" != "no" ]; then
				echo -en "${green}Enter Minimum-unused [${yellow}Default: 1${green}]: ${rest}"
				read -r min_un
				min_un=${min_un:-1}
			fi
			echo -e "${cyan}============================${rest}"
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
                "port": $remote_port,
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
                "minimum-unused": $min_un
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
		echo -e "${cyan}============================${rest}"
		echo -en "${green}Enter the local (${yellow}Connection${green}) port: ${rest}"
		read -r local_port
		echo -en "${green}Enter the remote (${yellow}Server Config${green}) port: ${rest}"
		read -r remote_port
		echo -en "${green}Do you want to Enable Http2 ? (yes/no) [${yellow}Default: yes${green}] : ${rest}"
		read -r http2
		http2=${http2:-yes}

		if [ "$http2" == "yes" ]; then
			output="h2server"
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
            "name": "h2server",
            "type": "Http2Server",
            "settings": {},
            "next": "pbserver"
        },
        {
            "name": "pbserver",
            "type": "ProtoBufServer",
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
		echo -e "${yellow}If you haven't already, you should get [SSL CERTIFICATE] for your domain in the main menu.${rest}"
	}

	# Function to create tls multi port iran
	create_tls_multi_port_iran() {
		echo -e "${cyan}============================${rest}"
		echo -en "${green}Enter Your Domain: ${rest}"
		read -r domain
		echo -en "${green}Enter the starting local port [${yellow}greater than 23${green}]: ${rest}"
		read -r start_port
		echo -en "${green}Enter the ending local port [${yellow}less than 65535${green}]: ${rest}"
		read -r end_port
		echo -en "${green}Enter the remote address: ${rest}"
		read -r remote_address
		echo -en "${green}Enter the remote (${yellow}Connection${green}) port: ${rest}"
		read -r remote_port
		echo -en "${green}Do you want to Enable Http2 ? (yes/no) [${yellow}Default: yes${green}] : ${rest}"
		read -r http2
		http2=${http2:-yes}
		if [ "$http2" == "no" ]; then
			echo -en "${green}Do you want to Enable PreConnect ? (yes/no) [${yellow}Default: yes${green}]: ${rest}"
			read -r PreConnect
			PreConnect=${PreConnect:-yes}
			if [ "$PreConnect" != "no" ]; then
				echo -en "${green}Enter Minimum-unused [${yellow}Default: 1${green}]: ${rest}"
				read -r min_un
				min_un=${min_un:-1}
			fi
			echo -e "${cyan}============================${rest}"
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
                "port": [$start_port,$end_port],
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
                "port": $remote_port,
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
                "minimum-unused": $min_un
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
                "alpn":"$alpn"
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
		echo -e "${cyan}============================${rest}"
		echo -en "${green}Enter the local (${yellow}Connection${green}) port: ${rest}"
		read -r local_port
		echo -en "${green}Do you want to Enable Http2 ? (yes/no) [${yellow}Default: yes${green}] : ${rest}"
		read -r http2
		http2=${http2:-yes}

		if [ "$http2" == "yes" ]; then
			output="h2server"
		else
			output="port_header"
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
            "next": "$output"
        },
EOF
		)

		if [ "$http2" == "yes" ]; then
			json+=$(
				cat <<EOF

		{
            "name": "h2server",
            "type": "Http2Server",
            "settings": {},
            "next": "pbserver"
        },
        {
            "name": "pbserver",
            "type": "ProtoBufServer",
            "settings": {},
            "next": "port_header"
        },
EOF
			)
		fi

		json+=$(
			cat <<EOF

	{
            "name":"port_header",
            "type": "HeaderServer",
            "settings": {
                "override": "dest_context->port"
            },
            "next": "output"
        },
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
		echo -e "${yellow}If you haven't already, you should get [SSL CERTIFICATE] for your domain in the main menu.${rest}"
	}

	echo -e "1. ${cyan} Tls port to port Iran${rest}"
	echo -e "2. ${White} Tls port to port kharej${rest}"
	echo -e "3. ${cyan} Tls Multiport iran${rest}"
	echo -e "4. ${White} Tls Multiport kharej${rest}"
	echo -e "0. ${cyan} Back to Main Menu${rest}"
	echo -en "${Purple} Enter your choice (1-4): ${rest}"
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
		echo -e "${cyan}==============================================${rest}"
		echo -en "${green}Press Enter to continue, or Ctrl+C to cancel.${rest}"
		read -r
		if [ -d ~/Waterwall/cert ] || [ -f ~/.acme/acme.sh ]; then
			echo -e "${cyan}============================${rest}"
			echo -en "${green}Do you want to delete the Domain Certificates? (yes/no): ${rest}"
			read -r delete_cert

			if [[ "$delete_cert" == "yes" ]]; then
				echo -e "${cyan}============================${rest}"
				echo -en "${green}Enter Your domain: ${rest}"
				read -r domain

				rm -rf ~/.acme.sh/"${domain}"_ecc
				rm -rf ~/Waterwall/cert
				echo -e "${green}Certificate for ${domain} has been deleted.${rest}"
			fi
		fi

		rm -rf ~/Waterwall/{core.json,config.json,Waterwall,log/}
		systemctl stop Waterwall.service >/dev/null 2>&1
		systemctl disable Waterwall.service >/dev/null 2>&1
		rm -rf /etc/systemd/system/Waterwall.service >/dev/null 2>&1
		echo -e "${cyan}============================${rest}"
		echo -e "${green}Waterwall has been uninstalled successfully.${rest}"
		echo -e "${cyan}============================${rest}"
	else
		echo -e "${cyan}============================${rest}"
		echo -e "${red}Waterwall is not installed.${rest}"
		echo -e "${cyan}============================${rest}"
	fi
}

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

[Install]
WantedBy=multi-user.target
EOL

	# Reload systemctl daemon and start the service
	sudo systemctl daemon-reload
	sudo systemctl restart trojan.service >/dev/null 2>&1
}

# Check Install service
check_install_service() {
	if [ -f /etc/systemd/system/Waterwall.service ]; then
		echo -e "${cyan}===================================${rest}"
		echo -e "${red}Please uninstall the existing Waterwall service before continuing.${rest}"
		echo -e "${cyan}===================================${rest}"
		exit 1
	fi
}

# Check tunnel status
check_tunnel_status() {
	# Check the status of the tunnel service
	if sudo systemctl is-active --quiet Waterwall.service; then
		echo -e "${yellow}     Waterwall :${green} [running ✔] ${rest}"
	else
		echo -e "${yellow}     Waterwall: ${red} [Not running ✗ ] ${rest}"
	fi
}

# Check Waterwall status
check_waterwall_status() {
	sleep 1
	# Check the status of the tunnel service
	if sudo systemctl is-active --quiet Waterwall.service; then
		echo -e "${cyan}Waterwall Installed successfully :${green} [running ✔] ${rest}"
		echo -e "${cyan}============================================${rest}"
	else
		echo -e "${yellow}Waterwall is not installed or ${red}[Not running ✗ ] ${rest}"
		echo -e "${cyan}==============================================${rest}"
	fi
}

# Main Menu

main() {
	clear
    
echo  "
══════════════════════════════════════════════════════════════════════════════════════
        ____                             _     _                                     
    ,   /    )                           /|   /                                  /   
-------/____/---_--_----__---)__--_/_---/-| -/-----__--_/_-----------__---)__---/-__-
  /   /        / /  ) /   ) /   ) /    /  | /    /___) /   | /| /  /   ) /   ) /(    
_/___/________/_/__/_(___(_/_____(_ __/___|/____(___ _(_ __|/_|/__(___/_/_____/___\__

══════════════════════════════════════════════════════════════════════════════════════"

	echo ""
	check_tunnel_status
	echo ""
    echo ""

	echo -e "${cyan}1. Tls Tunnel${rest}"
	echo -e "${White}2. SSL Certificate Management${rest}"
	echo -e "${cyan}3. Uninstall Waterwall${rest}"
	echo -e "${White}0. Exit${rest}"
	echo -en "${Purple}Enter your choice (1-3): ${rest}"
	read -r choice

	case $choice in
	1)
		check_install_service
		tls
		;;
	2)
		ssl_cert_issue_main
		;;
	3)
		uninstall_waterwall
		;;
	0)
		echo -e "${cyan}Exit..${rest}"
		exit
		;;
	*)
		echo -e "${Purple}Invalid choice!${rest}"
		;;
	esac
}
main
