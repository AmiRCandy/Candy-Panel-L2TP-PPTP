#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

REPO_URL="https://github.com/AmiRCandy/Candy-Panel-L2TP-PPTP.git"
PROJECT_DIR="Candy-Panel-L2TP-PPTP"
WEB_ROOT="/var/www/candy-panel"

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root.${NC}"
   exit 1
fi

show_help() {
    echo -e "${YELLOW}Usage: sudo ./setup.sh [option]${NC}"
    echo ""
    echo "Options:"
    echo "  install    Pull the code from GitHub and install the Candy Panel backend and required services."
    echo "  update     Pull the latest code from GitHub and update the system packages and services."
    echo "  uninstall  Completely remove the Candy Panel and all its components."
    echo ""
}

install_panel() {
    echo -e "${GREEN}Starting installation of PPTP and L2TP VPN...${NC}"
    apt update
    apt install -y git nginx lua-cjson lua-sqlite3 lua5.3 sqlite3

    if [ ! -d "$PROJECT_DIR" ]; then
        echo -e "${GREEN}Cloning the project from GitHub...${NC}"
        git clone "$REPO_URL"
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to clone the repository. Exiting.${NC}"
            exit 1
        fi
    fi
    cd "$PROJECT_DIR"

    echo -e "${GREEN}Setting up web server directories...${NC}"
    mkdir -p "${WEB_ROOT}/backend"
    mkdir -p "${WEB_ROOT}/frontend"
    cp -r Backend/* "${WEB_ROOT}/backend/"
    cp Frontend/index.html "${WEB_ROOT}/frontend/"
    chmod -R 755 "${WEB_ROOT}"

    # Configure Nginx
    echo -e "${GREEN}Configuring Nginx...${NC}"
    cp "${WEB_ROOT}/backend/conf/ngnix.conf" /etc/nginx/sites-available/candy-panel.conf
    ln -s /etc/nginx/sites-available/candy-panel.conf /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    systemctl restart nginx

    echo -e "${GREEN}Setting up the background sync task...${NC}"
    cp sync_worker.lua /usr/local/bin/sync_worker.lua
    chmod +x /usr/local/bin/sync_worker.lua
    
    (crontab -l 2>/dev/null; echo "* * * * * /usr/bin/lua /usr/local/bin/sync_worker.lua >> /var/log/candy_sync.log 2>&1") | crontab -

    echo -e "${GREEN}Installing required VPN packages...${NC}"
    apt install -y pptpd strongswan xl2tpd

    echo -e "${GREEN}Configuring network forwarding and firewall rules...${NC}"
    sysctl -w net.ipv4.ip_forward=1
    echo 1 > /proc/sys/net/ipv4/ip_forward
    iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    ufw allow 1723/tcp
    ufw allow proto 47
    ufw allow 500/udp
    ufw allow 4500/udp
    ufw allow 1701/udp

    echo -e "${GREEN}Enabling and starting VPN services...${NC}"
    systemctl enable pptpd
    systemctl enable xl2tpd
    systemctl enable strongswan
    systemctl restart pptpd
    systemctl restart xl2tpd
    systemctl restart strongswan
    
    echo -e "${GREEN}Installation finished. PPTP and L2TP/IPsec servers are installed.${NC}"
}

update_panel() {
  echo -e "${GREEN}Starting update process...${NC}"

    if [ ! -d "$WEB_ROOT" ]; then
        echo -e "${RED}Project directory not found. Please run 'sudo ./setup.sh install' first.${NC}"
        exit 1
    fi

    echo -e "${GREEN}Pulling the latest code from GitHub...${NC}"
    cd "$PROJECT_DIR"
    git pull

    echo -e "${GREEN}Updating and upgrading system packages...${NC}"
    apt update && apt upgrade -y

    echo -e "${GREEN}Copying updated files...${NC}"
    cp -r Backend/* "${WEB_ROOT}/backend/"
    cp index.html "${WEB_ROOT}/frontend/"

    echo -e "${GREEN}Restarting Nginx and VPN services...${NC}"
    systemctl restart nginx
    systemctl restart pptpd
    systemctl restart xl2tpd
    systemctl restart strongswan

    echo -e "${GREEN}Update completed successfully.${NC}"
}

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
    rm -f /etc/nginx/sites-available/candy-panel.conf
    rm -f /etc/nginx/sites-enabled/candy-panel.conf
    rm -f /usr/local/bin/sync_worker.lua

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

case "$1" in
    install)
        install_panel
        ;;
    update)
        update_panel
        ;;
    uninstall)
        uninstall_panel
        ;;
    *)
        show_help
        ;;
esac