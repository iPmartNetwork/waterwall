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
		echo -e "${cyan}════════════════════════════════════════════${rest}"
		echo -en "${green}Please enter your domain name to revoke the certificate: ${rest}"
		read -r domain
		~/.acme.sh/acme.sh --revoke -d "${domain}"
		if [ $? -ne 0 ]; then
			echo -e "${cyan}════════════════════════════════════════════${rest}"
			echo -e "${red}Failed to revoke certificate. Please check logs.${rest}"
		else
			echo -e "${cyan}════════════════════════════════════════════${rest}"
			echo -e "${green}Certificate revoked${rest}"
		fi
		;;
	3)
		local domain=""
		echo -e "${cyan}════════════════════════════════════════════${rest}"
		echo -en "${green}Please enter your domain name to forcefully renew an SSL certificate: ${rest}"
		read -r domain
		~/.acme.sh/acme.sh --renew -d "${domain}" --force
		if [ $? -ne 0 ]; then
			echo -e "${cyan}════════════════════════════════════════════${rest}"
			echo -e "${red}Failed to renew certificate. Please check logs.${rest}"
		else
			echo -e "${cyan}════════════════════════════════════════════${rest}"
			echo -e "${green}Certificate renewed${rest}"
		fi
		;;
	*) echo -e "${red}Invalid choice${rest}" ;;
	esac
}

ssl_cert_issue() {
	echo -e "${cyan}════════════════════════════════════════════${rest}"
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
		echo -e "${cyan}════════════════════════════════════════════${rest}"
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
	echo -e "${cyan}════════════════════════════════════════════${rest}"
	echo -en "${green}Please choose which port you want to use [${yellow}Default: 80${green}]: ${rest}"
	read -r WebPort
	WebPort=${WebPort:-80}
	if [[ ${WebPort} -gt 65535 || ${WebPort} -lt 1 ]]; then
		echo -e "${red}your input ${WebPort} is invalid,will use default port${rest}"
		WebPort=80
	fi
	echo -e "${green} will use port:${WebPort} to issue certs,please make sure this port is open...${rest}"
	echo -e "${cyan}════════════════════════════════════════════${rest}"
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

#1
#Reverse CDN Tunnel
reverse_cdn() {
	create_reverse_tls_grpc_singleport_iran() {
		echo -e "${cyan}════════════════════════════════════════════${rest}"
		echo -en "${green}Enter the local port: ${rest}"
		read -r local_port

		install_waterwall

		json=$(
			cat <<EOF
{
    "name": "config_reverse_tls_grpc_singleport_iran",
    "nodes": [
        {
            "name": "inbound_users",
            "type": "TcpListener",
            "settings": {
                "address": "0.0.0.0",
                "port": $local_port,
                "nodelay": true
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
            "name": "grpc_server",
            "type": "ProtoBufServer",
            "settings": {},
            "next": "reverse_server"
        },
        {
            "name": "h2server",
            "type": "Http2Server",
            "settings": {},
            "next": "grpc_server"
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
                "fallback-intence-delay": 0
            },
            "next": "h2server"
        },
        {
            "name": "inbound_cloudflare",
            "type": "TcpListener",
            "settings": {
                "address": "0.0.0.0",
                "port": 443,
                "nodelay": true,
                "whitelist": [
                    "173.245.48.0/20",
                    "103.21.244.0/22",
                    "103.22.200.0/22",
                    "103.31.4.0/22",
                    "141.101.64.0/18",
                    "108.162.192.0/18",
                    "190.93.240.0/20",
                    "188.114.96.0/20",
                    "197.234.240.0/22",
                    "198.41.128.0/17",
                    "162.158.0.0/15",
                    "104.16.0.0/13",
                    "104.24.0.0/14",
                    "172.64.0.0/13",
                    "131.0.72.0/22",
                    "2400:cb00::/32",
                    "2606:4700::/32",
                    "2803:f800::/32",
                    "2405:b500::/32",
                    "2405:8100::/32",
                    "2a06:98c0::/29",
                    "2c0f:f248::/32"
                ]
            },
            "next": "sslserver"
        }
    ]
}
EOF
		)
		echo "$json" >/root/Waterwall/config.json
		echo -e "1. ${cyan} If you haven't already, you should get [SSL CERTIFICATE] for your domain in the main menu.${rest}"
		echo -e "2. ${White} Enable [grpc] in CloudFlare Network Setting${rest}"
		echo -e "3. ${cyan} Enable Minimum TLS Version [TlS 1.2] in CloudFlare Edge Certificate Setting${rest}"
		echo -e "4. ${White} Enable [Proxy status] in CloudFlare Dns Record Setting${rest}"
		echo -e "5. ${cyan} Wait at least 5 minutes to apply Changes in CloudFlare${rest}"
		echo -e "${cyan}════════════════════════════════════════════${rest}"
	}

	create_reverse_tls_grpc_singleport_kharej() {
		echo -e "${cyan}════════════════════════════════════════════${rest}"
		echo -en "${green}Enter your remote domain: ${rest}"
		read -r domain
		echo -en "${green}Enter the local (${yellow}Config${green}) port: ${rest}"
		read -r local_port

		install_waterwall

		json=$(
			cat <<EOF
{
    "name": "config_reverse_tls_grpc_singleport_kharej",
    "nodes": [
        {
            "name": "core_outbound",
            "type": "TcpConnector",
            "settings": {
                "nodelay": true,
                "address": "127.0.0.1",
                "port": $local_port
            }
        },
        {
            "name": "bridge1",
            "type": "Bridge",
            "settings": {
                "pair": "bridge2"
            },
            "next": "core_outbound"
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
            },
            "next": "grpc_client"
        },
        {
            "name": "grpc_client",
            "type": "ProtoBufClient",
            "settings": {},
            "next": "h2client"
        },
        {
            "name": "h2client",
            "type": "Http2Client",
            "settings": {
                "host": "$domain",
                "port": 443,
                "path": "/service",
                "content-type": "application/grpc"
            },
            "next": "sslclient"
        },
        {
            "name": "sslclient",
            "type": "OpenSSLClient",
            "settings": {
                "sni": "$domain",
                "verify": true,
                "alpn": "h2"
            },
            "next": "iran_outbound"
        },
        {
            "name": "iran_outbound",
            "type": "TcpConnector",
            "settings": {
                "nodelay": true,
                "address": "$domain",
                "port": 443
            }
        }
    ]
}
EOF
		)
		echo "$json" >/root/Waterwall/config.json
	}

	create_reverse_tls_grpc_multiport_kharej() {
		echo -e "${cyan}════════════════════════════════════════════${rest}"
		echo -en "${green}Enter your remote domain: ${rest}"
		read -r domain

		install_waterwall

		json=$(
			cat <<EOF
{
    "name": "config_reverse_tls_grpc_multiport_kharej",
    "nodes": [
        {
            "name": "core_outbound",
            "type": "TcpConnector",
            "settings": {
                "nodelay": true,
                "address": "127.0.0.1",
                "port": "dest_context->port"
            }
        },
        {
            "name": "port_header",
            "type": "HeaderServer",
            "settings": {
                "override": "dest_context->port"
            },
            "next": "core_outbound"
        },
        {
            "name": "bridge1",
            "type": "Bridge",
            "settings": {
                "pair": "bridge2"
            },
            "next": "port_header"
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
            },
            "next": "grpc_client"
        },
        {
            "name": "grpc_client",
            "type": "ProtoBufClient",
            "settings": {},
            "next": "h2client"
        },
        {
            "name": "h2client",
            "type": "Http2Client",
            "settings": {
                "host": "$domain",
                "port": 443,
                "path": "/service",
                "content-type": "application/grpc"
            },
            "next": "sslclient"
        },
        {
            "name": "sslclient",
            "type": "OpenSSLClient",
            "settings": {
                "sni": "$domain",
                "verify": true,
                "alpn": "h2"
            },
            "next": "iran_outbound"
        },
        {
            "name": "iran_outbound",
            "type": "TcpConnector",
            "settings": {
                "nodelay": true,
                "address": "$domain",
                "port": 443
            }
        }
    ]
}
EOF
		)
		echo "$json" >/root/Waterwall/config.json
	}

	create_reverse_tls_grpc_multiport_iran() {
		echo -e "${cyan}════════════════════════════════════════════${rest}"
		echo -en "${green}Enter the starting local port [${yellow}greater than 23${green}]: ${rest}"
		read -r start_port
		echo -en "${green}Enter the ending local port [${yellow}less than 65535${green}]: ${rest}"
		read -r end_port

		install_waterwall

		json=$(
			cat <<EOF
{
    "name": "config_reverse_tls_grpc_multiport_iran",
    "nodes": [
        {
            "name": "inbound_users",
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
            "name": "grpc_server",
            "type": "ProtoBufServer",
            "settings": {},
            "next": "reverse_server"
        },
        {
            "name": "h2server",
            "type": "Http2Server",
            "settings": {},
            "next": "grpc_server"
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
                "fallback-intence-delay": 0
            },
            "next": "h2server"
        },
        {
            "name": "inbound_cloudflare",
            "type": "TcpListener",
            "settings": {
                "address": "0.0.0.0",
                "port": 443,
                "nodelay": true,
                "whitelist": [
                    "173.245.48.0/20",
                    "103.21.244.0/22",
                    "103.22.200.0/22",
                    "103.31.4.0/22",
                    "141.101.64.0/18",
                    "108.162.192.0/18",
                    "190.93.240.0/20",
                    "188.114.96.0/20",
                    "197.234.240.0/22",
                    "198.41.128.0/17",
                    "162.158.0.0/15",
                    "104.16.0.0/13",
                    "104.24.0.0/14",
                    "172.64.0.0/13",
                    "131.0.72.0/22",
                    "2400:cb00::/32",
                    "2606:4700::/32",
                    "2803:f800::/32",
                    "2405:b500::/32",
                    "2405:8100::/32",
                    "2a06:98c0::/29",
                    "2c0f:f248::/32"
                ]
            },
            "next": "sslserver"
        }
    ]
}
EOF
		)
		echo "$json" >/root/Waterwall/config.json
		echo -e "1. ${cyan} If you haven't already, you should get [SSL CERTIFICATE] for your domain in the main menu.${rest}"
		echo -e "2. ${White} Enable [grpc] in CloudFlare Network Setting${rest}"
		echo -e "3. ${cyan} Enable Minimum TLS Version [TlS 1.2] in CloudFlare Edge Certificate Setting${rest}"
		echo -e "4. ${White} Enable [Proxy status] in CloudFlare Dns Record Setting${rest}"
		echo -e "5. ${cyan} Wait at least 5 minutes to apply Changes in CloudFlare${rest}"
		echo -e "${cyan}════════════════════════════════════════════${rest}"
	}

	create_reverse_tls_grpc_multiport_hd_iran() {
		echo -e "${cyan}════════════════════════════════════════════${rest}"
		echo -en "${green}Enter the starting local port [${yellow}greater than 23${green}]: ${rest}"
		read -r start_port
		echo -en "${green}Enter the ending local port [${yellow}less than 65535${green}]: ${rest}"
		read -r end_port

		install_waterwall

		json=$(
			cat <<EOF
{
    "name": "config_reverse_tls_grpc_multiport_hd_iran",
    "nodes": [
        {
            "name": "inbound_users",
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
            "name": "halfs",
            "type": "HalfDuplexServer",
            "settings": {},
            "next": "reverse_server"
        },
        {
            "name": "grpc_server",
            "type": "ProtoBufServer",
            "settings": {},
            "next": "halfs"
        },
        {
            "name": "h2server",
            "type": "Http2Server",
            "settings": {},
            "next": "grpc_server"
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
                "fallback-intence-delay": 0
            },
            "next": "h2server"
        },
        {
            "name": "inbound_cloudflare",
            "type": "TcpListener",
            "settings": {
                "address": "0.0.0.0",
                "port": 443,
                "nodelay": true,
                "whitelist": [
                    "173.245.48.0/20",
                    "103.21.244.0/22",
                    "103.22.200.0/22",
                    "103.31.4.0/22",
                    "141.101.64.0/18",
                    "108.162.192.0/18",
                    "190.93.240.0/20",
                    "188.114.96.0/20",
                    "197.234.240.0/22",
                    "198.41.128.0/17",
                    "162.158.0.0/15",
                    "104.16.0.0/13",
                    "104.24.0.0/14",
                    "172.64.0.0/13",
                    "131.0.72.0/22",
                    "2400:cb00::/32",
                    "2606:4700::/32",
                    "2803:f800::/32",
                    "2405:b500::/32",
                    "2405:8100::/32",
                    "2a06:98c0::/29",
                    "2c0f:f248::/32"
                ]
            },
            "next": "sslserver"
        }
    ]
}
EOF
		)
		echo "$json" >/root/Waterwall/config.json
		echo -e "1. ${cyan} If you haven't already, you should get [SSL CERTIFICATE] for your domain in the main menu.${rest}"
		echo -e "2. ${White} Enable [grpc] in CloudFlare Network Setting${rest}"
		echo -e "3. ${cyan} Enable Minimum TLS Version [TlS 1.2] in CloudFlare Edge Certificate Setting${rest}"
		echo -e "4. ${White} Enable [Proxy status] in CloudFlare Dns Record Setting${rest}"
		echo -e "5. ${cyan} Wait at least 5 minutes to apply Changes in CloudFlare${rest}"
		echo -e "${cyan}════════════════════════════════════════════${rest}"
	}

	create_reverse_tls_grpc_multiport_hd_kharej() {
		echo -e "${cyan}════════════════════════════════════════════${rest}"
		echo -en "${green}Enter your remote domain: ${rest}"
		read -r domain

		install_waterwall

		json=$(
			cat <<EOF
{
    "name": "config_reverse_tls_grpc_multiport_hd_kharej",
    "nodes": [
        {
            "name": "core_outbound",
            "type": "TcpConnector",
            "settings": {
                "nodelay": true,
                "address": "127.0.0.1",
                "port": "dest_context->port"
            }
        },
        {
            "name": "port_header",
            "type": "HeaderServer",
            "settings": {
                "override": "dest_context->port"
            },
            "next": "core_outbound"
        },
        {
            "name": "bridge1",
            "type": "Bridge",
            "settings": {
                "pair": "bridge2"
            },
            "next": "port_header"
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
            },
            "next": "halfc"
        },
        {
            "name": "halfc",
            "type": "HalfDuplexClient",
            "settings": {},
            "next": "grpc_client"
        },
        {
            "name": "grpc_client",
            "type": "ProtoBufClient",
            "settings": {},
            "next": "h2client"
        },
        {
            "name": "h2client",
            "type": "Http2Client",
            "settings": {
                "host": "$domain",
                "port": 443,
                "path": "/service",
                "content-type": "application/grpc"
            },
            "next": "sslclient"
        },
        {
            "name": "sslclient",
            "type": "OpenSSLClient",
            "settings": {
                "sni": "$domain",
                "verify": true,
                "alpn": "h2"
            },
            "next": "iran_outbound"
        },
        {
            "name": "iran_outbound",
            "type": "TcpConnector",
            "settings": {
                "nodelay": true,
                "address": "$domain",
                "port": 443
            }
        }
    ]
}
EOF
		)
		echo "$json" >/root/Waterwall/config.json
	}

    echo -e "${cyan}════════════════════════════════════════════${rest}"
	echo -e "1. ${cyan} Reverse tls grpc Multiport iran${rest}"
	echo -e "2. ${White} Reverse tls grpc Multiport kharej${rest}"
	echo -e "3. ${cyan} Reverse tls grpc Multiport HD iran${rest}"
	echo -e "4. ${White} Reverse tls grpc Multiport HD kharej${rest}"
	echo -e "0. ${cyan} Back to Main Menu${rest}"
	echo -en "${Purple} Enter your choice (1-4): ${rest}"
	read -r choice
    echo -e "${cyan}════════════════════════════════════════════${rest}"
	case $choice in
	1)
		create_reverse_tls_grpc_multiport_iran
		waterwall_service
		;;
	2)
		create_reverse_tls_grpc_multiport_kharej
		waterwall_service
		;;
	3)
		create_reverse_tls_grpc_multiport_hd_iran
		waterwall_service
		;;
	4)
		create_reverse_tls_grpc_multiport_hd_kharej
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
		echo -en "${green}Press Enter to continue, or Ctrl+C to cancel.${rest}"
		read -r
		if [ -d ~/Waterwall/cert ] || [ -f ~/.acme/acme.sh ]; then
			echo -e "${cyan}════════════════════════════════════════════${rest}"
			echo -en "${green}Do you want to delete the Domain Certificates? (yes/no): ${rest}"
			read -r delete_cert

			if [[ "$delete_cert" == "yes" ]]; then
				echo -e "${cyan════════════════════════════════════════════${rest}"
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
		echo -e "${cyan}════════════════════════════════════════════${rest}"
		echo -e "${green}Waterwall has been uninstalled successfully.${rest}"
		echo -e "${cyan}════════════════════════════════════════════${rest}"
	else
		echo -e "${cyan}════════════════════════════════════════════${rest}"
		echo -e "${red}Waterwall is not installed.${rest}"
		echo -e "${cyan}════════════════════════════════════════════${rest}"
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
		echo -e "${cyan}════════════════════════════════════════════${rest}"
		echo -e "${red}Please uninstall the existing Waterwall service before continuing.${rest}"
		echo -e "${cyan}════════════════════════════════════════════${rest}"
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
		echo -e "${cyan}════════════════════════════════════════════${rest}"
	else
		echo -e "${yellow}Waterwall is not installed or ${red}[Not running ✗ ] ${rest}"
		echo -e "${cyan}════════════════════════════════════════════${rest}"
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

	echo -e "${cyan}1. Reverse CDN Tunnel${rest}"
	echo -e "${White}2. SSL Certificate Management${rest}"
	echo -e "${cyan}3. Uninstall Waterwall${rest}"
	echo -e "${White}0. Exit${rest}"
	echo -en "${Purple}Enter your choice (1-3): ${rest}"
	read -r choice

	case $choice in
	1)
		check_install_service
		reverse_cdn
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
