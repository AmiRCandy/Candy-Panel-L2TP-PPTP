#!/bin/bash

# Define color codes for better terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Project and directory variables
REPO_URL="https://github.com/AmiRCandy/Candy-Panel-L2TP-PPTP.git"
PROJECT_DIR="Candy-Panel-L2TP-PPTP"
WEB_ROOT="/var/www/candy-panel"
NGINX_SITES_AVAILABLE="/etc/nginx/sites-available"
NGINX_SITES_ENABLED="/etc/nginx/sites-enabled"
SYNC_WORKER_PATH="/usr/local/bin/sync_worker.lua"
NGINX_CONF_PATH="/etc/nginx/sites-available/candy-panel.conf"

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root.${NC}"
   exit 1
fi

# Function to check and install a package
check_and_install_package() {
    PACKAGE=$1
    if ! dpkg -s "$PACKAGE" &>/dev/null; then
        echo -e "${YELLOW}Package '$PACKAGE' not found. Installing...${NC}"
        if ! apt-get install -y "$PACKAGE"; then
            echo -e "${RED}Failed to install '$PACKAGE'. Aborting.${NC}"
            exit 1
        fi
    fi
}

# Function to check and install all required dependencies
check_and_install_dependencies() {
    echo -e "${GREEN}Updating package lists and installing core dependencies...${NC}"
    apt update
    check_and_install_package "git"
    check_and_install_package "dialog"
    check_and_install_package "nginx"
    check_and_install_package "lua5.3"
    check_and_install_package "sqlite3"
    check_and_install_package "lua-cjson"
    check_and_install_package "lua-sql-sqlite3" # This might be named differently on some systems
    check_and_install_package "strongswan"
    check_and_install_package "xl2tpd"
    check_and_install_package "pptpd"
    check_and_install_package "iptables"
    check_and_install_package "ufw"
    check_and_install_package "libstrongswan-extra-plugins" # This might be named differently
}

# Display the interactive menu
show_menu() {
    CMD=(dialog --menu "Candy Panel Setup Menu" 22 76 16)
    OPTIONS=(1 "Install the Candy Panel backend and services"
             2 "Update the system packages and panel"
             3 "Completely remove the Candy Panel"
             4 "Exit")
    CHOICE=$("${CMD[@]}" "${OPTIONS[@]}" 2>&1 >/dev/tty)
}

# Installation function
install_panel() {
    echo -e "${GREEN}Starting installation of PPTP and L2TP VPN...${NC}"

    # Clone the repository
    if [ ! -d "$PROJECT_DIR" ]; then
        echo -e "${GREEN}Cloning the project from GitHub...${NC}"
        if ! git clone "$REPO_URL"; then
            echo -e "${RED}Failed to clone the repository. Exiting.${NC}"
            exit 1
        fi
    fi
    cd "$PROJECT_DIR" || { echo -e "${RED}Failed to change directory. Exiting.${NC}"; exit 1; }

    # Set up web server directories and copy files
    echo -e "${GREEN}Setting up web server directories and permissions...${NC}"
    mkdir -p "${WEB_ROOT}/backend"
    mkdir -p "${WEB_ROOT}/frontend"
    cp -r Backend/* "${WEB_ROOT}/backend/" || { echo -e "${RED}Failed to copy backend files. Exiting.${NC}"; exit 1; }
    cp Frontend/index.html "${WEB_ROOT}/frontend/" || { echo -e "${RED}Failed to copy frontend file. Exiting.${NC}"; exit 1; }
    chmod -R 755 "${WEB_ROOT}"

    # Configure Nginx
    echo -e "${GREEN}Configuring Nginx...${NC}"
    cp "${WEB_ROOT}/backend/conf/ngnix.conf" "$NGINX_CONF_PATH" || { echo -e "${RED}Failed to copy Nginx config file. Exiting.${NC}"; exit 1; }
    ln -s "$NGINX_CONF_PATH" "$NGINX_SITES_ENABLED/candy-panel.conf" || { echo -e "${RED}Failed to create Nginx symlink. Exiting.${NC}"; exit 1; }
    rm -f "$NGINX_SITES_ENABLED/default"
    systemctl restart nginx || { echo -e "${RED}Failed to restart Nginx. Check its status with 'systemctl status nginx'.${NC}"; exit 1; }

    # Set up background sync task
    echo -e "${GREEN}Setting up the background sync task...${NC}"
    if [ -f "sync_worker.lua" ]; then
        cp sync_worker.lua "$SYNC_WORKER_PATH" || { echo -e "${RED}Failed to copy sync_worker.lua. Exiting.${NC}"; exit 1; }
        chmod +x "$SYNC_WORKER_PATH"
        (crontab -l 2>/dev/null; echo "* * * * * /usr/bin/lua $SYNC_WORKER_PATH >> /var/log/candy_sync.log 2>&1") | crontab -
    else
        echo -e "${RED}Error: 'sync_worker.lua' not found in the cloned repository. Skipping cron job setup.${NC}"
    fi

    # Configure network forwarding and firewall
    echo -e "${GREEN}Configuring network forwarding and firewall rules...${NC}"
    sysctl -w net.ipv4.ip_forward=1
    echo 1 > /proc/sys/net/ipv4/ip_forward
    iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    ufw allow 1723/tcp
    ufw allow proto 47
    ufw allow 500/udp
    ufw allow 4500/udp
    ufw allow 1701/udp

    # Enable and start VPN services
    echo -e "${GREEN}Enabling and starting VPN services...${NC}"
    systemctl enable pptpd strongswan xl2tpd
    systemctl restart pptpd strongswan xl2tpd

    echo -e "${GREEN}Installation finished. PPTP and L2TP/IPsec servers are installed.${NC}"
}

# Update function
update_panel() {
    echo -e "${GREEN}Starting update process...${NC}"
    if [ ! -d "$WEB_ROOT" ]; then
        echo -e "${RED}Project directory not found. Please run 'Install' first.${NC}"
        exit 1
    fi
    if [ ! -d "$PROJECT_DIR" ]; then
        echo -e "${RED}Cloned repository directory not found. Exiting.${NC}"
        exit 1
    fi

    echo -e "${GREEN}Pulling the latest code from GitHub...${NC}"
    cd "$PROJECT_DIR"
    git pull || { echo -e "${RED}Failed to pull latest code. Exiting.${NC}"; exit 1; }

    echo -e "${GREEN}Updating and upgrading system packages...${NC}"
    apt update && apt upgrade -y

    echo -e "${GREEN}Copying updated files...${NC}"
    cp -r Backend/* "${WEB_ROOT}/backend/"
    cp Frontend/index.html "${WEB_ROOT}/frontend/"

    echo -e "${GREEN}Restarting Nginx and VPN services...${NC}"
    systemctl restart nginx || { echo -e "${RED}Failed to restart Nginx.${NC}"; }
    systemctl restart pptpd || { echo -e "${RED}Failed to restart pptpd.${NC}"; }
    systemctl restart xl2tpd || { echo -e "${RED}Failed to restart xl2tpd.${NC}"; }
    systemctl restart strongswan || { echo -e "${RED}Failed to restart strongswan.${NC}"; }

    echo -e "${GREEN}Update completed successfully.${NC}"
}

# Uninstallation function
uninstall_panel() {
    echo -e "${RED}WARNING: This will completely remove all VPN services and data.${NC}"
    read -p "Are you sure you want to proceed? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]
    then
        echo -e "${YELLOW}Uninstallation cancelled.${NC}"
        exit 1
    fi

    echo -e "${RED}Stopping and disabling VPN services...${NC}"
    systemctl stop pptpd strongswan xl2tpd nginx
    systemctl disable pptpd strongswan xl2tpd nginx

    echo -e "${RED}Removing VPN packages...${NC}"
    apt purge -y pptpd strongswan xl2tpd nginx git

    echo -e "${RED}Removing project directory, database, and configuration files...${NC}"
    rm -rf "$WEB_ROOT"
    rm -f /etc/ppp/chap-secrets
    rm -f "$NGINX_CONF_PATH"
    rm -f "$NGINX_SITES_ENABLED/candy-panel.conf"
    rm -f "$SYNC_WORKER_PATH"

    echo -e "${RED}Removing cron job...${NC}"
    crontab -l | grep -v 'sync_worker.lua' | crontab -

    echo -e "${RED}Removing firewall rules...${NC}"
    ufw delete allow 1723/tcp
    ufw delete allow proto 47
    ufw delete allow 500/udp
    ufw delete allow 4500/udp
    ufw delete allow 1701/udp
    iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

    echo -e "${GREEN}Uninstallation completed.${NC}"
}

# Main execution loop
check_and_install_dependencies

while true
do
  show_menu
  case $CHOICE in
    1)
        install_panel
        ;;
    2)
        update_panel
        ;;
    3)
        uninstall_panel
        ;;
    4)
        break
        ;;
    *)
        echo -e "${RED}Invalid option selected. Please choose a number from the menu.${NC}"
        ;;
  esac
  read -p "Press any key to return to the menu..."
done