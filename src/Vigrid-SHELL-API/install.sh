#!/bin/bash
# =============================================================================
# Vigrid Shell API -- Installation Script
# =============================================================================
# Installs the API into the chosen directories, creates a Python virtual
# environment, installs dependencies, and registers a systemd service.
#
# Usage:  ./install.sh <install_dir> <config_dir>
# Example: ./install.sh /opt/vigrid-shell-api /etc/vigrid-shell-api
# =============================================================================
set -euo pipefail

SERVICE_NAME="vigrid-shell-api"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- helpers ----------------------------------------------------------------
usage()     { echo "Usage: $0 <install_dir> <config_dir>"; exit 1; }
log_info()  { echo "[INFO]  $1"; }
log_warn()  { echo "[WARN]  $1"; }
log_error() { echo "[ERROR] $1" >&2; }

# ---- argument validation ----------------------------------------------------
[ $# -ne 2 ] && { log_error "Exactly 2 arguments required."; usage; }

INSTALL_DIR="$(realpath -m "$1")"
CONFIG_DIR="$(realpath -m "$2")"

[ "$(id -u)" -ne 0 ] && { log_error "Must be run as root."; exit 1; }

SOURCE_REAL="$(realpath "$SCRIPT_DIR")"
[ "$INSTALL_DIR" = "$SOURCE_REAL" ] && {
    log_error "Install directory must differ from the source directory."; exit 1; }

log_info "============================================="
log_info "Vigrid Shell API -- Installation"
log_info "============================================="
log_info "Source : $SCRIPT_DIR"
log_info "Install: $INSTALL_DIR"
log_info "Config : $CONFIG_DIR"
log_info "============================================="

# ---- prerequisites ----------------------------------------------------------
log_info "Checking prerequisites..."
command -v python3 &>/dev/null || { log_error "python3 not found."; exit 1; }

PY_MINOR=$(python3 -c 'import sys; print(sys.version_info.minor)')
PY_MAJOR=$(python3 -c 'import sys; print(sys.version_info.major)')
(( PY_MAJOR < 3 || PY_MINOR < 8 )) && { log_error "Python 3.8+ required."; exit 1; }

if ! python3 -c "import venv" &>/dev/null; then
    log_warn "python3-venv not found, attempting install..."
    if command -v apt-get &>/dev/null; then
        apt-get update -qq && apt-get install -y -qq python3-venv
    else
        log_error "Cannot install python3-venv automatically."; exit 1
    fi
fi

# ---- create directories ----------------------------------------------------
log_info "Creating directories..."
mkdir -p "$INSTALL_DIR" "$CONFIG_DIR"

# ---- copy application files -------------------------------------------------
log_info "Copying application files..."
cp "$SCRIPT_DIR/vigrid-shell-api.py" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/requirements.txt"    "$INSTALL_DIR/"
chmod 750 "$INSTALL_DIR/vigrid-shell-api.py"

# Copy documentation, test script, and uninstall script into install dir
[ -f "$SCRIPT_DIR/API-DOCUMENTATION.md" ] && \
    cp "$SCRIPT_DIR/API-DOCUMENTATION.md" "$INSTALL_DIR/"
[ -f "$SCRIPT_DIR/test-api.sh" ] && {
    cp "$SCRIPT_DIR/test-api.sh" "$INSTALL_DIR/"
    chmod 750 "$INSTALL_DIR/test-api.sh"
}
cp "$SCRIPT_DIR/uninstall.sh" "$INSTALL_DIR/"
chmod 750 "$INSTALL_DIR/uninstall.sh"

# ---- configuration ----------------------------------------------------------
if [ -f "$CONFIG_DIR/vigrid-shell-api.conf" ]; then
    log_warn "Configuration already exists. Saving new template as .conf.new"
    cp "$SCRIPT_DIR/vigrid-shell-api.conf" "$CONFIG_DIR/vigrid-shell-api.conf.new"
else
    log_info "Installing default configuration..."
    cp "$SCRIPT_DIR/vigrid-shell-api.conf" "$CONFIG_DIR/vigrid-shell-api.conf"
fi
chmod 640 "$CONFIG_DIR/vigrid-shell-api.conf"

# ---- Python virtual environment ---------------------------------------------
log_info "Creating Python virtual environment..."
[ -d "$INSTALL_DIR/venv" ] && { log_warn "Removing existing venv..."; rm -rf "$INSTALL_DIR/venv"; }
python3 -m venv "$INSTALL_DIR/venv"

log_info "Installing Python dependencies..."
"$INSTALL_DIR/venv/bin/pip" install --upgrade pip --quiet 2>/dev/null
"$INSTALL_DIR/venv/bin/pip" install -r "$INSTALL_DIR/requirements.txt" --quiet 2>/dev/null
log_info "Dependencies installed."

# ---- systemd service --------------------------------------------------------
if command -v systemctl &>/dev/null; then
    log_info "Installing systemd service..."
    sed -e "s|__INSTALL_DIR__|${INSTALL_DIR}|g" \
        -e "s|__CONFIG_DIR__|${CONFIG_DIR}|g" \
        "$SCRIPT_DIR/vigrid-shell-api.service.template" \
        > "/etc/systemd/system/${SERVICE_NAME}.service"
    chmod 644 "/etc/systemd/system/${SERVICE_NAME}.service"
    systemctl daemon-reload
    log_info "Service installed: ${SERVICE_NAME}.service"
else
    log_warn "systemctl not found -- skipping service installation."
fi

# ---- log file ---------------------------------------------------------------
log_info "Ensuring log file..."
mkdir -p /var/log
touch "/var/log/${SERVICE_NAME}.log"
chmod 640 "/var/log/${SERVICE_NAME}.log"

# ---- installation metadata --------------------------------------------------
cat > "$INSTALL_DIR/.install-metadata" <<EOF
INSTALL_DIR=$INSTALL_DIR
CONFIG_DIR=$CONFIG_DIR
INSTALL_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SOURCE_DIR=$SCRIPT_DIR
EOF
chmod 640 "$INSTALL_DIR/.install-metadata"

# ---- done -------------------------------------------------------------------
log_info "============================================="
log_info "Installation complete!"
log_info "============================================="
log_info "App    : $INSTALL_DIR/vigrid-shell-api.py"
log_info "Config : $CONFIG_DIR/vigrid-shell-api.conf"
log_info "Venv   : $INSTALL_DIR/venv/"
log_info "Service: /etc/systemd/system/${SERVICE_NAME}.service"
log_info "Log    : /var/log/${SERVICE_NAME}.log"
log_info "Tests  : $INSTALL_DIR/test-api.sh"
log_info "Docs   : $INSTALL_DIR/API-DOCUMENTATION.md"
log_info ""
log_info "Edit the config then: systemctl start ${SERVICE_NAME}"
