#!/bin/bash

# Pterodactyl Panel Interactive Installer
# Version: 2.0
# Compatible with: Ubuntu 20.04/22.04, Debian 11/12

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to validate IP address
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if ((octet > 255)); then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

# Function to validate domain
validate_domain() {
    local domain=$1
    if [[ $domain =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        return 0
    else
        return 1
    fi
}

# Banner
show_banner() {
    clear
    echo -e "${PURPLE}"
    echo "==========================================================="
    echo "    ____  __                        __            __      "
    echo "   / __ \/ /____  _________  ____  / /___ ___  __/ /__    "
    echo "  / /_/ / __/ _ \/ ___/ __ \/ __ \/ __/ / / / /_/ / / /    "
    echo " / ____/ /_/  __/ /  / /_/ / /_/ / /_/ /_/ / __  /_/ /_    "
    echo "/_/    \__/\___/_/   \____/\____/\__/\__, /\____(_)_(_)    "
    echo "                                   /____/                 "
    echo "                                                          "
    echo "           Interactive Panel Installer v2.0              "
    echo "==========================================================="
    echo -e "${NC}"
}

# Function to collect user input
collect_info() {
    echo -e "${CYAN}Please provide the following information:${NC}"
    echo ""
    
    # Get IP Address
    while true; do
        read -p "$(echo -e ${WHITE}"Server IP Address: "${NC})" SERVER_IP
        if [[ -z "$SERVER_IP" ]]; then
            print_error "IP Address cannot be empty!"
            continue
        fi
        if validate_ip "$SERVER_IP"; then
            break
        else
            print_error "Invalid IP address format! Please enter a valid IP."
        fi
    done
    
    # Get Provider
    read -p "$(echo -e ${WHITE}"VPS Provider (e.g., DigitalOcean, AWS, Vultr): "${NC})" VPS_PROVIDER
    if [[ -z "$VPS_PROVIDER" ]]; then
        VPS_PROVIDER="Unknown"
    fi
    
    # Get Region
    read -p "$(echo -e ${WHITE}"Server Region (e.g., Singapore, New York): "${NC})" SERVER_REGION
    if [[ -z "$SERVER_REGION" ]]; then
        SERVER_REGION="Unknown"
    fi
    
    # Get Domain
    while true; do
        read -p "$(echo -e ${WHITE}"Domain (leave empty to use IP only): "${NC})" PANEL_DOMAIN
        if [[ -z "$PANEL_DOMAIN" ]]; then
            PANEL_DOMAIN=""
            USE_DOMAIN=false
            break
        elif validate_domain "$PANEL_DOMAIN"; then
            USE_DOMAIN=true
            break
        else
            print_error "Invalid domain format! Please enter a valid domain or leave empty."
        fi
    done
    
    # Get admin email
    if [[ "$USE_DOMAIN" == true ]]; then
        read -p "$(echo -e ${WHITE}"Admin Email (default: admin@${PANEL_DOMAIN}): "${NC})" ADMIN_EMAIL
        if [[ -z "$ADMIN_EMAIL" ]]; then
            ADMIN_EMAIL="admin@${PANEL_DOMAIN}"
        fi
    else
        read -p "$(echo -e ${WHITE}"Admin Email: "${NC})" ADMIN_EMAIL
        if [[ -z "$ADMIN_EMAIL" ]]; then
            ADMIN_EMAIL="admin@${SERVER_IP}"
        fi
    fi
    
    echo ""
    echo -e "${CYAN}Installation Summary:${NC}"
    echo -e "${WHITE}IP Address:${NC} $SERVER_IP"
    echo -e "${WHITE}Provider:${NC} $VPS_PROVIDER"
    echo -e "${WHITE}Region:${NC} $SERVER_REGION"
    if [[ "$USE_DOMAIN" == true ]]; then
        echo -e "${WHITE}Domain:${NC} $PANEL_DOMAIN"
        echo -e "${WHITE}Panel URL:${NC} https://$PANEL_DOMAIN"
    else
        echo -e "${WHITE}Domain:${NC} Not configured (using IP)"
        echo -e "${WHITE}Panel URL:${NC} http://$SERVER_IP"
    fi
    echo -e "${WHITE}Admin Email:${NC} $ADMIN_EMAIL"
    echo ""
    
    read -p "$(echo -e ${WHITE}"Continue with installation? (y/N): "${NC})" CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        print_error "Installation cancelled by user."
        exit 1
    fi
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root!"
        print_warning "Please run: sudo bash $0"
        exit 1
    fi
}

# Detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        print_error "Cannot detect OS!"
        exit 1
    fi
    
    print_status "Detected OS: $OS $VER"
    
    # Check if OS is supported
    case "$OS" in
        *"Ubuntu"*)
            if [[ "$VER" != "20.04" && "$VER" != "22.04" ]]; then
                print_warning "Ubuntu $VER may not be fully supported. Recommended: 20.04 or 22.04"
            fi
            ;;
        *"Debian"*)
            if [[ "$VER" != "11" && "$VER" != "12" ]]; then
                print_warning "Debian $VER may not be fully supported. Recommended: 11 or 12"
            fi
            ;;
        *)
            print_error "Unsupported OS: $OS"
            print_warning "This installer supports Ubuntu 20.04/22.04 and Debian 11/12"
            exit 1
            ;;
    esac
}

# Install dependencies
install_dependencies() {
    print_status "Updating system packages..."
    apt update && apt upgrade -y
    
    print_status "Installing required packages..."
    apt install -y software-properties-common curl apt-transport-https ca-certificates gnupg lsb-release wget unzip tar
    
    # Install Docker
    print_status "Installing Docker..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Start Docker
    systemctl start docker
    systemctl enable docker
    
    # Add PHP repository
    print_status "Adding PHP repository..."
    add-apt-repository -y ppa:ondrej/php
    apt update
    
    # Install PHP and extensions
    print_status "Installing PHP 8.2 and extensions..."
    apt install -y php8.2 php8.2-cli php8.2-gd php8.2-mysql php8.2-pdo php8.2-mbstring php8.2-tokenizer php8.2-bcmath php8.2-xml php8.2-fpm php8.2-curl php8.2-zip php8.2-intl php8.2-sqlite3
    
    # Install Composer
    print_status "Installing Composer..."
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
    
    # Install MariaDB
    print_status "Installing MariaDB..."
    apt install -y mariadb-server mariadb-client
    
    # Install Nginx
    print_status "Installing Nginx..."
    apt install -y nginx
    
    # Install Redis
    print_status "Installing Redis..."
    apt install -y redis-server
    
    # Install Certbot if domain is provided
    if [[ "$USE_DOMAIN" == true ]]; then
        print_status "Installing Certbot for SSL..."
        apt install -y certbot python3-certbot-nginx
    fi
}

# Start services
start_services() {
    print_status "Starting services..."
    systemctl start mariadb nginx redis-server php8.2-fpm
    systemctl enable mariadb nginx redis-server php8.2-fpm
}

# Configure database
setup_database() {
    print_status "Configuring MariaDB..."
    
    # Generate random passwords
    DB_ROOT_PASSWORD=$(openssl rand -base64 32)
    DB_USER_PASSWORD=$(openssl rand -base64 32)
    
    # Secure MariaDB installation
    mysql -e "UPDATE mysql.user SET Password=PASSWORD('${DB_ROOT_PASSWORD}') WHERE User='root';"
    mysql -e "DELETE FROM mysql.user WHERE User='';"
    mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    mysql -e "DROP DATABASE IF EXISTS test;"
    mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';"
    mysql -e "FLUSH PRIVILEGES;"
    
    # Create database and user
    print_status "Creating database and user..."
    mysql -u root -p"${DB_ROOT_PASSWORD}" <<EOF
CREATE DATABASE panel;
CREATE USER 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '${DB_USER_PASSWORD}';
GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1' WITH GRANT OPTION;
FLUSH PRIVILEGES;
exit
EOF
}

# Install Pterodactyl Panel
install_panel() {
    print_status "Downloading Pterodactyl Panel..."
    mkdir -p /var/www/pterodactyl
    cd /var/www/pterodactyl
    
    # Get latest release
    LATEST_VERSION=$(curl -s https://api.github.com/repos/pterodactyl/panel/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    print_status "Installing Pterodactyl Panel $LATEST_VERSION"
    
    curl -Lo panel.tar.gz "https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz"
    tar -xzf panel.tar.gz
    chmod -R 755 storage/* bootstrap/cache/
    
    # Install dependencies
    print_status "Installing Pterodactyl dependencies..."
    composer install --no-dev --optimize-autoloader --no-interaction
    
    # Setup environment
    print_status "Setting up environment..."
    cp .env.example .env
    
    # Generate encryption key
    php artisan key:generate --force
    
    # Configure environment
    if [[ "$USE_DOMAIN" == true ]]; then
        sed -i "s|APP_URL=.*|APP_URL=https://${PANEL_DOMAIN}|g" .env
    else
        sed -i "s|APP_URL=.*|APP_URL=http://${SERVER_IP}|g" .env
    fi
    
    sed -i "s|DB_HOST=.*|DB_HOST=127.0.0.1|g" .env
    sed -i "s|DB_PORT=.*|DB_PORT=3306|g" .env
    sed -i "s|DB_DATABASE=.*|DB_DATABASE=panel|g" .env
    sed -i "s|DB_USERNAME=.*|DB_USERNAME=pterodactyl|g" .env
    sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=${DB_USER_PASSWORD}|g" .env
    
    # Setup cache and sessions
    sed -i "s|CACHE_DRIVER=.*|CACHE_DRIVER=redis|g" .env
    sed -i "s|SESSION_DRIVER=.*|SESSION_DRIVER=redis|g" .env
    sed -i "s|QUEUE_CONNECTION=.*|QUEUE_CONNECTION=redis|g" .env
    
    # Database migration
    print_status "Running database migrations..."
    php artisan migrate --seed --force
    
    # Generate admin password
    ADMIN_PASSWORD=$(openssl rand -base64 16)
    
    # Create admin user
    print_status "Creating admin user..."
    php artisan p:user:make --email="${ADMIN_EMAIL}" --username=admin --name-first=Admin --name-last=User --password="${ADMIN_PASSWORD}" --admin=1
    
    # Set correct permissions
    print_status "Setting permissions..."
    chown -R www-data:www-data /var/www/pterodactyl/*
}

# Configure web server
configure_nginx() {
    print_status "Configuring Nginx..."
    
    if [[ "$USE_DOMAIN" == true ]]; then
        # Configuration with domain
        cat > /etc/nginx/sites-available/pterodactyl.conf <<EOF
server_tokens off;

server {
    listen 80;
    server_name ${PANEL_DOMAIN};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${PANEL_DOMAIN};

    root /var/www/pterodactyl/public;
    index index.html index.htm index.php;
    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    access_log off;
    error_log  /var/log/nginx/pterodactyl.app-error.log error;

    client_max_body_size 100m;
    client_body_timeout 120s;

    sendfile off;

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
    else
        # Configuration with IP only
        cat > /etc/nginx/sites-available/pterodactyl.conf <<EOF
server {
    listen 80;
    server_name ${SERVER_IP};

    root /var/www/pterodactyl/public;
    index index.html index.htm index.php;
    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    access_log off;
    error_log  /var/log/nginx/pterodactyl.app-error.log error;

    client_max_body_size 100m;
    client_body_timeout 120s;

    sendfile off;

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
    fi
    
    # Enable site and disable default
    ln -sf /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
    rm -f /etc/nginx/sites-enabled/default
    
    # Test Nginx configuration
    nginx -t
}

# Setup queue worker
setup_queue() {
    print_status "Setting up queue worker..."
    cat > /etc/systemd/system/pteroq.service <<EOF
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service

[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

    systemctl enable --now pteroq.service
    
    # Setup cron
    print_status "Setting up cron..."
    (crontab -u www-data -l 2>/dev/null; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1") | crontab -u www-data -
}

# Get SSL certificate
setup_ssl() {
    if [[ "$USE_DOMAIN" == true ]]; then
        print_status "Getting SSL certificate..."
        certbot --nginx -d "${PANEL_DOMAIN}" --non-interactive --agree-tos --email "${ADMIN_EMAIL}" --redirect
    fi
}

# Final restart
final_restart() {
    print_status "Restarting services..."
    systemctl restart nginx php8.2-fpm
}

# Show installation summary
show_summary() {
    clear
    echo -e "${GREEN}"
    echo "==========================================================="
    echo "    🎉 INSTALLATION COMPLETED SUCCESSFULLY! 🎉"
    echo "==========================================================="
    echo -e "${NC}"
    
    echo -e "${WHITE}Server Information:${NC}"
    echo -e "${CYAN}IP Address:${NC} $SERVER_IP"
    echo -e "${CYAN}Provider:${NC} $VPS_PROVIDER"
    echo -e "${CYAN}Region:${NC} $SERVER_REGION"
    echo ""
    
    echo -e "${WHITE}Panel Access:${NC}"
    if [[ "$USE_DOMAIN" == true ]]; then
        echo -e "${CYAN}Panel URL:${NC} https://$PANEL_DOMAIN"
    else
        echo -e "${CYAN}Panel URL:${NC} http://$SERVER_IP"
    fi
    echo -e "${CYAN}Admin Email:${NC} $ADMIN_EMAIL"
    echo -e "${CYAN}Admin Password:${NC} $ADMIN_PASSWORD"
    echo ""
    
    echo -e "${WHITE}Database Information:${NC}"
    echo -e "${CYAN}Database:${NC} panel"
    echo -e "${CYAN}DB User:${NC} pterodactyl"
    echo -e "${CYAN}DB Password:${NC} $DB_USER_PASSWORD"
    echo -e "${CYAN}Root Password:${NC} $DB_ROOT_PASSWORD"
    echo ""
    
    echo -e "${YELLOW}⚠️  IMPORTANT SECURITY NOTES:${NC}"
    echo -e "${WHITE}1.${NC} Change the admin password immediately after first login"
    echo -e "${WHITE}2.${NC} Save the database passwords in a secure location"
    echo -e "${WHITE}3.${NC} Configure firewall rules (UFW recommended)"
    if [[ "$USE_DOMAIN" == false ]]; then
        echo -e "${WHITE}4.${NC} Consider setting up a domain and SSL certificate"
    fi
    echo ""
    
    echo -e "${WHITE}Next Steps:${NC}"
    echo -e "${WHITE}1.${NC} Login to your panel and change the admin password"
    echo -e "${WHITE}2.${NC} Configure your first server location"
    echo -e "${WHITE}3.${NC} Install Wings on your game servers"
    echo ""
    
    echo -e "${WHITE}Wings Installation Command:${NC}"
    echo -e "${CYAN}curl -sSL https://get.docker.com/ | CHANNEL=stable bash${NC}"
    echo -e "${CYAN}systemctl enable --now docker${NC}"
    echo -e "${CYAN}mkdir -p /etc/pterodactyl${NC}"
    echo -e "${CYAN}curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64${NC}"
    echo -e "${CYAN}chmod u+x /usr/local/bin/wings${NC}"
    echo ""
    
    echo -e "${GREEN}==========================================================="
    echo "              Thank you for using Pterodactyl!"
    echo "==========================================================="
    echo -e "${NC}"
    
    # Save credentials to file
    cat > /root/pterodactyl-credentials.txt <<EOF
Pterodactyl Panel Installation Summary
=====================================
Generated on: $(date)

Server Information:
IP Address: $SERVER_IP
Provider: $VPS_PROVIDER
Region: $SERVER_REGION

Panel Access:
$(if [[ "$USE_DOMAIN" == true ]]; then echo "Panel URL: https://$PANEL_DOMAIN"; else echo "Panel URL: http://$SERVER_IP"; fi)
Admin Email: $ADMIN_EMAIL
Admin Password: $ADMIN_PASSWORD

Database Information:
Database: panel
DB User: pterodactyl
DB Password: $DB_USER_PASSWORD
Root Password: $DB_ROOT_PASSWORD

IMPORTANT: Change the admin password after first login!
EOF

    print_success "Credentials saved to: /root/pterodactyl-credentials.txt"
}

# Main installation function
main() {
    show_banner
    check_root
    collect_info
    detect_os
    install_dependencies
    start_services
    setup_database
    install_panel
    configure_nginx
    setup_queue
    setup_ssl
    final_restart
    show_summary
}

# Run the installation
main "$@"
