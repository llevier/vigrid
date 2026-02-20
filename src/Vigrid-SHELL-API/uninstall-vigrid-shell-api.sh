#!/bin/bash
#
# Vigrid Shell API - Uninstall Script
# This script removes the Vigrid Shell API service
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

INSTALL_DIR="%%VSTORAGE_GNS3%%/bin/Vigrid-SHELL-API"
CONFIG_DIR="%%VSTORAGE_GNS3%%/etc"
SERVICE_NAME="vigrid-shell-api"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

stop_service() {
    log_info "Stopping service..."
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        systemctl stop "$SERVICE_NAME"
        log_info "Service stopped"
    else
        log_info "Service not running"
    fi
}

disable_service() {
    log_info "Disabling service..."
    if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
        systemctl disable "$SERVICE_NAME"
        log_info "Service disabled"
    else
        log_info "Service not enabled"
    fi
}

remove_service_file() {
    log_info "Removing systemd service file..."
    if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
        rm -f "/etc/systemd/system/$SERVICE_NAME.service"
        systemctl daemon-reload
        log_info "Service file removed"
    fi
}

remove_installation_directory() {
    log_info "Removing installation directory..."
    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
        log_info "Installation directory removed"
    fi
}

remove_config() {
    log_warn "Do you want to remove the configuration file? (y/N)"
    read -r response
    if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
        if [ -f "$CONFIG_DIR/vigrid-shell-api.conf" ]; then
            rm -f "$CONFIG_DIR/vigrid-shell-api.conf"
            log_info "Configuration file removed"
        fi
    else
        log_info "Configuration file kept"
    fi
}

remove_log() {
    log_warn "Do you want to remove the log file? (y/N)"
    read -r response
    if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
        if [ -f "/var/log/vigrid-shell-api.log" ]; then
            rm -f /var/log/vigrid-shell-api.log
            log_info "Log file removed"
        fi
    else
        log_info "Log file kept"
    fi
}

remove_sudoers() {
    log_info "Checking for sudoers entry..."
    if [ -f "/etc/sudoers.d/vigrid-shell-api" ]; then
        rm -f /etc/sudoers.d/vigrid-shell-api
        log_info "Sudoers entry removed"
    fi
}

uninstall() {
    log_info "Starting uninstallation of Vigrid Shell API..."
    
    check_root
    stop_service
    disable_service
    remove_service_file
    remove_installation_directory
    remove_sudoers
    
    log_info "Uninstallation completed successfully!"
    log_info "Note: Configuration and log files were kept (answer accordingly next time to remove them)"
}

uninstall
