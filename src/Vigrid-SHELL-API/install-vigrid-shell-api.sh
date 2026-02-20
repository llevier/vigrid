#!/bin/bash
#
# Vigrid Shell API - Installation Script
# This script installs the Vigrid Shell API as a systemd service
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/Vstorage/GNS3/bin/Vigrid-SHELL-API"
GNS3_DIR="/Vstorage/GNS3"
CONFIG_DIR="/Vstorage/GNS3/etc"
LOG_DIR="/var/log"
SERVICE_NAME="vigrid-shell-api"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

search_vigrid-update() {
    VU=`find / -name vigrid-update`
    [ "x$VU" = "x" ] && log_error "I cant find vigrid-update, exiting" && exit 1
    VU_DIR=`dirname $VU`

    GNS3_DIR=`echo "$VU_DIR" | awk -F '/' '{print "/"$2"/"$3;}'`
    log_info "GNS3 directory is be $GNS3_DIR..."

    INSTALL_DIR="$GNS3_DIR/bin/Vigrid-SHELL-API"
    log_info "Installation directory will be $INSTALL_DIR..."

    CONFIG_DIR="$GNS3_DIR/etc"
    log_info "Configuration directory will be $CONFIG_DIR..."
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

create_directories() {
    log_info "Creating directories..."
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$(dirname /var/log/vigrid-shell-api.log)"
}

install_files() {
    log_info "Installing files..."

    BIN_DIR=`dirname $INSTALL_DIR`
    files=("README-vigrid-shell-api.md" "test-vigrid-shell-api.sh" "uninstall-vigrid-shell-api.sh")

    for file in "${files[@]}"; do
        if [ ! -f "$SCRIPT_DIR/$file" ]; then
	        log_error "$file not found in $SCRIPT_DIR"
	        exit 1
	    fi
        cp "$SCRIPT_DIR/$file" "$BIN_DIR/"
	sed -i "s:%%VSTORAGE_GNS3%%:$GNS3_DIR:g" $BIN_DIR/$file
    done
    
    if [ ! -f "$SCRIPT_DIR/vigrid-shell-api.py" ]; then
        log_error "vigrid-shell-api.py not found in $SCRIPT_DIR"
        exit 1
    fi
    
    cp "$SCRIPT_DIR/vigrid-shell-api.py" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/vigrid-shell-api.py"
    
    if [ -f "$SCRIPT_DIR/vigrid-shell-api.conf" ]; then
        cp "$SCRIPT_DIR/vigrid-shell-api.conf" "$CONFIG_DIR/"
    else
        log_warn "Configuration file not found, using default"
    fi
    
    cp "$SCRIPT_DIR/vigrid-shell-api.service" "/etc/systemd/system/"
    sed -i "s:%%VSTORAGE_GNS3%%:$GNS3_DIR:g" "/etc/systemd/system/vigrid-shell-api.service"
}

setup_python() {
    log_info "Setting up Python virtual environment..."
    
    if ! command -v python3 &> /dev/null; then
        log_info "Python3 not found, installing..."
        apt-get update
        apt-get install -y python3 python3-venv python3-pip
    fi
    
    if ! python3 -m pip --version &> /dev/null; then
        log_info "Python3 pip module not found, installing..."
        apt-get update
        apt-get install -y python3-pip
    fi
    
    if ! python3 -m venv --help &> /dev/null; then
        log_info "Python3 venv module not found, installing..."
        apt-get update
        apt-get install -y python3-venv
    fi
    
    cd "$INSTALL_DIR"
    
    if [ -d "venv" ]; then
        log_info "Virtual environment already exists"
    else
        python3 -m venv venv
    fi
    
    log_info "Installing Python dependencies..."
    ./venv/bin/pip install --quiet flask configparser
    
    log_info "Python virtual environment ready"
}

setup_permissions() {
    log_info "Setting up permissions..."
    
    RUN_AS_USER=$(grep "^run_as_user" "$CONFIG_DIR/vigrid-shell-api.conf" 2>/dev/null | cut -d'=' -f2 | tr -d ' ' || echo "root")
    
    if [ "$RUN_AS_USER" != "root" ]; then
        if id "$RUN_AS_USER" &>/dev/null; then
            chown -R "$RUN_AS_USER:$RUN_AS_USER" "$INSTALL_DIR"
            chown "$RUN_AS_USER:$RUN_AS_USER" "$CONFIG_DIR/vigrid-shell-api.conf"
            chown "$RUN_AS_USER:$RUN_AS_USER" /var/log/vigrid-shell-api.log
            log_info "Permissions set for user: $RUN_AS_USER"
        else
            log_warn "User $RUN_AS_USER does not exist, using root"
            RUN_AS_USER="root"
        fi
    else
        chown -R root:root "$INSTALL_DIR"
        chown root:root "$CONFIG_DIR/vigrid-shell-api.conf"
    fi
    
    if [ -n "$RUN_AS_USER" ] && [ "$RUN_AS_USER" != "root" ]; then
        if ! grep -q "^$RUN_AS_USER ALL=(ALL) NOPASSWD: ALL" /etc/sudoers 2>/dev/null; then
            log_warn "User $RUN_AS_USER needs sudo access without password"
            echo "$RUN_AS_USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/vigrid-shell-api
        fi
    fi
}

reload_systemd() {
    log_info "Reloading systemd daemon..."
    systemctl daemon-reload
}

install() {
    log_info "Starting installation of Vigrid Shell API..."
    
    check_root
    search_vigrid-update
    create_directories
    install_files
    setup_python
    setup_permissions
    reload_systemd
    
    log_info "Installation completed successfully!"
    log_info ""
    log_info "To start the service: systemctl start $SERVICE_NAME"
    log_info "To enable at boot: systemctl enable $SERVICE_NAME"
    log_info "To check status: systemctl status $SERVICE_NAME"
    log_info ""
    log_info "Configuration file: $CONFIG_DIR/vigrid-shell-api.conf"
    log_info "Log file: /var/log/vigrid-shell-api.log"
}

install
