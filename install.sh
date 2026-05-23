#!/bin/bash
# BatchVentoyDeployer installer
# Run once as root to install dependencies and set up the environment.
# Usage: sudo ./install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/config/defaults.conf"
source "$SCRIPT_DIR/lib/ui.sh"
source "$SCRIPT_DIR/lib/ventoy.sh"

# Superuser check
if [ "$(id -u)" -ne 0 ]; then
  ui_error "install.sh must be run as root. Try: sudo ./install.sh"
  exit 1
fi

# Handle --update flag
FORCE_UPDATE=false
if [ "${1:-}" = "--update" ]; then
  FORCE_UPDATE=true
  ui_msg "Update flag set: re-running full setup."
fi

printf "=== BatchVentoyDeployer installer ===\n\n"

# Create ISO source directory
if [ ! -d "$ISO_SRC" ]; then
  mkdir -p "$ISO_SRC"
  chown "$REAL_USER":"$REAL_USER" "$ISO_SRC"
  ui_success "Created ISO directory at: $ISO_SRC"
else
  ui_msg "ISO directory already exists at: $ISO_SRC"
fi

# Install dependencies
ui_msg "Installing dependencies..."
apt-get update -qq
if apt-get install -y curl zenity rsync exfat-fuse exfatprogs parted; then
  ui_success "Dependencies installed."
else
  ui_error "Failed to install dependencies."
  exit 1
fi

# Reading back SUMMON_COMMAND to get the old command name on --update
marker_version=$(sed -n '1p' "$MARKER_FILE" 2>/dev/null || true)

# Download and extract Ventoy (skip if marker matches and not forced)
if [ "$FORCE_UPDATE" = true ] || [ ! -f "$MARKER_FILE" ] || [ "$marker_version" != "$VENTOY_VERSION" ] || [ ! -d "/usr/local/share/$APP_NAME/$VENTOY_DIR" ]; then
  old_command=$(sed -n '2p' "$MARKER_FILE" 2>/dev/null || true)
  if [ -n "$old_command" ] && [ "$old_command" != "$SUMMON_COMMAND" ]; then
    rm -f "/usr/local/bin/$old_command"
  fi
  _vtmp=$(mktemp -d)
  (cd "$_vtmp" && ventoy_download && ventoy_extract)
  rm -rf "/usr/local/share/$APP_NAME/$VENTOY_DIR"
  mv "$_vtmp/$VENTOY_DIR" "/usr/local/share/$APP_NAME/"
  rm -rf "$_vtmp"
  ui_success "Ventoy moved to /usr/local/share/$APP_NAME/$VENTOY_DIR"
else
  ui_msg "Ventoy ${VENTOY_VERSION} already installed. Skipping download."
fi

# Install support files to system share directory
install -d "/usr/local/share/$APP_NAME/lib"
install -d "/usr/local/share/$APP_NAME/config"
if [ "$SCRIPT_DIR" != "/usr/local/share/$APP_NAME" ]; then
  install -m 644 "$SCRIPT_DIR/lib/"*.sh "/usr/local/share/$APP_NAME/lib/"
  install -m 644 "$SCRIPT_DIR/config/defaults.conf" "/usr/local/share/$APP_NAME/config/"
  install -m 755 "$SCRIPT_DIR/install.sh" "/usr/local/share/$APP_NAME/install.sh"
fi

# Install main script to PATH
install -m 755 "$SCRIPT_DIR/ventoy-creator.sh" "/usr/local/bin/$SUMMON_COMMAND"
ui_success "$APP_NAME installed to /usr/local/bin/$SUMMON_COMMAND"

# Write version and summon command to marker file
mkdir -p "$(dirname "$MARKER_FILE")"
printf "%s\n%s\n" "$VENTOY_VERSION" "$SUMMON_COMMAND" > "$MARKER_FILE"
ui_success "Marker written for Ventoy ${VENTOY_VERSION}."

printf "\n"
ui_success "Installation complete. Run 'sudo $SUMMON_COMMAND' to start."
