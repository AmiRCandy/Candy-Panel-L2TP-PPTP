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
SYNC_WORKER_PATH="/usr/local/bin/sync_worker.lua"
SERVICE_NAME="candy-panel.service"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"
LUA_BIN_PATH=$(which lua)

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
    check_and_install_package "lua5.3"
    check_and_install_package "sqlite3"
    check_and_install_package "strongswan"
    check_and_install_package "xl2tpd"
    check_and_install_package "pptpd"
    check_and_install_package "iptables"
    check_and_install_package "ufw"
    check_and_install_package "libstrongswan-extra-plugins"
    check_and_install_package "luarocks"
    check_and_install_package "libssl-dev"
    check_and_install_package "lua5.3-dev"
    check_and_install_package "libsqlite3-dev"

    echo -e "${GREEN}Installing Lua packages with Luarocks...${NC}"
    luarocks install lapis || { echo -e "${RED}Failed to install lapis. Aborting.${NC}"; exit 1; }
    luarocks install lua-cjson || { echo -e "${RED}Failed to install lua-cjson. Aborting.${NC}"; exit 1; }
    luarocks install lsqlite3 || { echo -e "${RED}Failed to install lsqlite3. Aborting.${NC}"; exit 1; }
    luarocks install lua-resty-http || { echo -e "${RED}Failed to install lua-resty-http. Aborting.${NC}"; exit 1; }
    luarocks install http || { echo -e "${RED}Failed to install http. Aborting.${NC}"; exit 1; }
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
    # Copy the new Lapis app file
    cp Backend/app.lua "${WEB_ROOT}/backend/app.lua" || { echo -e "${RED}Failed to copy app.lua. Exiting.${NC}"; exit 1; }
    chmod -R 755 "${WEB_ROOT}"

    # Set up background sync task
    echo -e "${GREEN}Setting up the background sync task...${NC}"
    if [ -f "${WEB_ROOT}/backend/sync_worker.lua" ]; then
        cp "${WEB_ROOT}/backend/sync_worker.lua" "$SYNC_WORKER_PATH" || { echo -e "${RED}Failed to copy sync_worker.lua. Exiting.${NC}"; exit 1; }
        chmod +x "$SYNC_WORKER_PATH"
        (crontab -l 2>/dev/null; echo "* * * * * /usr/bin/lua $SYNC_WORKER_PATH >> /var/log/candy_sync.log 2>&1") | crontab -
    else
        echo -e "${RED}Error: 'sync_worker.lua' not found. Skipping cron job setup.${NC}"
    fi

    # Create and enable the systemd service for Lapis
    echo -e "${GREEN}Creating and enabling systemd service for Lapis...${NC}"
    echo "[Unit]
Description=Candy Panel Lapis Web Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${WEB_ROOT}/backend
ExecStart=/usr/local/bin/lapis server
Restart=on-failure

[Install]
WantedBy=multi-user.target" > "$SERVICE_PATH"
    systemctl daemon-reload
    systemctl enable "${SERVICE_NAME}"
    systemctl start "${SERVICE_NAME}"

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
    ufw allow 8080/tcp # Allow traffic on Lapis default port

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
    cp Backend/app.lua "${WEB_ROOT}/backend/app.lua"

    echo -e "${GREEN}Restarting Lapis and VPN services...${NC}"
    systemctl restart "${SERVICE_NAME}" || { echo -e "${RED}Failed to restart Lapis service.${NC}"; }
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

    echo -e "${RED}Stopping and disabling services...${NC}"
    systemctl stop pptpd strongswan xl2tpd "${SERVICE_NAME}"
    systemctl disable pptpd strongswan xl2tpd "${SERVICE_NAME}"

    echo -e "${RED}Removing VPN packages and Lapis...${NC}"
    apt purge -y pptpd strongswan xl2tpd git luarocks
    luarocks remove lapis

    echo -e "${RED}Removing project directory, database, and configuration files...${NC}"
    rm -rf "$WEB_ROOT"
    rm -f /etc/ppp/chap-secrets
    rm -f "$SERVICE_PATH"
    rm -f "$SYNC_WORKER_PATH"
    rm -rf "$PROJECT_DIR"

    echo -e "${RED}Removing cron job...${NC}"
    crontab -l | grep -v 'sync_worker.lua' | crontab -

    echo -e "${RED}Removing firewall rules...${NC}"
    ufw delete allow 1723/tcp
    ufw delete allow proto 47
    ufw delete allow 500/udp
    ufw delete allow 4500/udp
    ufw delete allow 1701/udp
    ufw delete allow 8080/tcp

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