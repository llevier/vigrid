#!/bin/bash
# =============================================================================
# Vigrid Shell API -- Uninstallation Script
# =============================================================================
# Removes everything created by install.sh.  The source directory is untouched.
#
# Usage:  ./uninstall.sh <install_dir> <config_dir>
# Example: ./uninstall.sh /opt/vigrid-shell-api /etc/vigrid-shell-api
# =============================================================================
set -euo pipefail

SERVICE_NAME="vigrid-shell-api"

log_info()  { echo "[INFO]  $1"; }
log_warn()  { echo "[WARN]  $1"; }
log_error() { echo "[ERROR] $1" >&2; }

[ $# -ne 2 ] && { log_error "Usage: $0 <install_dir> <config_dir>"; exit 1; }

INSTALL_DIR="$(realpath -m "$1")"
CONFIG_DIR="$(realpath -m "$2")"

[ "$(id -u)" -ne 0 ] && { log_error "Must be run as root."; exit 1; }

log_info "============================================="
log_info "Vigrid Shell API -- Uninstallation"
log_info "============================================="
log_info "Install: $INSTALL_DIR"
log_info "Config : $CONFIG_DIR"
log_info "============================================="

# ---- stop & disable service -------------------------------------------------
if command -v systemctl &>/dev/null; then
    systemctl is-active  --quiet "$SERVICE_NAME" 2>/dev/null && {
        log_info "Stopping service..."; systemctl stop "$SERVICE_NAME"; }
    systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null && {
        log_info "Disabling service..."; systemctl disable "$SERVICE_NAME"; }
    SVC="/etc/systemd/system/${SERVICE_NAME}.service"
    [ -f "$SVC" ] && { log_info "Removing service file..."; rm -f "$SVC"; systemctl daemon-reload; }
fi

# ---- remove directories -----------------------------------------------------
[ -d "$INSTALL_DIR" ] && { log_info "Removing $INSTALL_DIR"; rm -rf "$INSTALL_DIR"; }
[ -d "$CONFIG_DIR"  ] && { log_info "Removing $CONFIG_DIR";  rm -rf "$CONFIG_DIR"; }

# ---- remove log files -------------------------------------------------------
for f in "/var/log/${SERVICE_NAME}.log" "/var/log/${SERVICE_NAME}.log."*; do
    [ -f "$f" ] && { log_info "Removing $f"; rm -f "$f"; }
done

log_info "============================================="
log_info "Uninstallation complete!"
log_info "============================================="
log_info "Source directory is untouched."
