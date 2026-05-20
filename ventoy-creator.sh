#!/bin/bash
# BatchVentoyDeployer — batch Ventoy USB creator
# Usage: sudo <summon_command> [--help|--update]

set -uo pipefail

BVD_DATA="/usr/local/share/batchventoydeployer"

source "$BVD_DATA/config/defaults.conf"
source "$BVD_DATA/lib/ui.sh"
source "$BVD_DATA/lib/disk.sh"
source "$BVD_DATA/lib/ventoy.sh"

# Logging: tee all output to log file
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

# Flag handling
case "${1:-}" in
  --update)
    exec sudo "/usr/local/share/$APP_NAME/install.sh" --update
    ;;
  --help|-h)
    printf "Usage: sudo %s [--help|--update]\n\n" "$SUMMON_COMMAND"
    printf "What this tool does:\n"
    printf "  Formats USB drives with Ventoy and copies ISO files onto them.\n"
    printf "  Select your drives, confirm once — it handles the rest unattended.\n\n"
    printf "Options:\n"
    printf "  --help, -h    Show this message and exit\n"
    printf "  --update      Re-download and reinstall Ventoy (run after a version change)\n\n"
    printf "Before running:\n"
    printf "  Place your .iso files in: %s\n\n" "$ISO_SRC"
    printf "Configuration (managed by your admin):\n"
    printf "  Ventoy version : %s\n" "$VENTOY_VERSION"
    printf "  ISO source     : %s\n" "$ISO_SRC"
    printf "  Log file       : %s\n" "$LOG_FILE"
    printf "  Config file    : /usr/local/share/%s/config/defaults.conf\n\n" "$APP_NAME"
    printf "  To change settings, open the config file as root:\n"
    printf "  sudo nano /usr/local/share/%s/config/defaults.conf\n" "$APP_NAME"
    exit 0
    ;;
esac

# Superuser check
if [ "$(id -u)" -ne 0 ]; then
  ui_error "This script must be run as root. Try: sudo $SUMMON_COMMAND"
  exit 1
fi

# Setup check
if [ ! -f "$MARKER_FILE" ] || [ "$(sed -n '1p' "$MARKER_FILE" 2>/dev/null || true)" != "$VENTOY_VERSION" ]; then
  ui_warn "Setup not complete or Ventoy version changed. Please run: sudo ./install.sh"
  exit 1
fi

# Initialise mount point variable before trap so cleanup is always safe
ventoy_mnt=""

# Trap for cleanup on interrupt
trap '
  ui_warn "Interrupted. Cleaning up..."
  if [ -n "$ventoy_mnt" ] && mountpoint -q "$ventoy_mnt" 2>/dev/null; then
    umount "$ventoy_mnt" 2>/dev/null
    rmdir "$ventoy_mnt" 2>/dev/null
  fi
  exit 1
' INT TERM

# Early ISO check, abort before touching any disks
iso_count=$(find "$ISO_SRC" -maxdepth 1 -name "*.iso" 2>/dev/null | wc -l)
if [ "$iso_count" -eq 0 ]; then
  ui_error "No ISO files found in $ISO_SRC. Add ISOs before running."
  exit 1
fi

# UI
ui_header
ui_list_disks
ui_prompt_disk_selection

if [ -z "$DISK_CHOICES" ]; then
  ui_msg "No disks selected. Exiting."
  exit 0
fi

# Validate all inputs up front before touching any disk
validated_choices=""
for choice in $DISK_CHOICES; do
  device="/dev/$choice"

  if ! disk_exists "$device"; then
    ui_error "$device does not exist or is not a block device. Skipping."
    continue
  fi

  if disk_is_system_disk "$device"; then
    ui_error "$device appears to be the system disk. Skipping."
    continue
  fi

  validated_choices="$validated_choices $choice"
done

validated_choices="${validated_choices# }"

if [ -z "$validated_choices" ]; then
  ui_error "No valid disks remaining after validation. Exiting."
  exit 1
fi

# Build device array and show single upfront confirmation
validated_devices=()
for choice in $validated_choices; do
  validated_devices+=("/dev/$choice")
done

if ! ui_confirm_selection "${validated_devices[@]}"; then
  ui_msg "Aborted."
  exit 0
fi

# Count drives for progress display
total=$(echo "$validated_choices" | wc -w)
current=0

for choice in $validated_choices; do
  current=$((current + 1))
  device="/dev/$choice"
  ventoy_mnt="/mnt/ventoy_$choice"

  printf "\n[%d/%d] Processing %s\n" "$current" "$total" "$device"

  # Install Ventoy
  ui_msg "Formatting $device with Ventoy..."
  sleep 1
  if ! ventoy_install_to "$device"; then
    ui_error "Ventoy installation failed for $device. Skipping."
    continue
  fi

  # Settle partition table
  udevadm settle --timeout=10
  sleep 2

  # Find Ventoy partition
  ventoy_part=$(disk_get_ventoy_part "$device")
  if [ -z "$ventoy_part" ]; then
    ui_error "Could not find Ventoy partition on $device. Skipping."
    continue
  fi

  # Mount
  if ! disk_mount "$ventoy_part" "$ventoy_mnt"; then
    ui_error "Failed to mount $ventoy_part. Skipping."
    ventoy_mnt=""
    continue
  fi

  # Space check
  required=$(disk_iso_total_size "$ISO_SRC")
  if ! disk_has_space "$ventoy_mnt" "$required"; then
    ui_error "Not enough space on $device for all ISOs. Skipping."
    disk_unmount "$ventoy_mnt"
    ventoy_mnt=""
    continue
  fi

  # Copy ISOs
  ui_msg "Copying ISOs from $ISO_SRC to $ventoy_mnt..."
  if ! disk_copy_isos "$ISO_SRC" "$ventoy_mnt"; then
    ui_error "Failed to copy ISOs to $device."
    disk_unmount "$ventoy_mnt"
    ventoy_mnt=""
    continue
  fi

  # Unmount
  disk_unmount "$ventoy_mnt"
  ventoy_mnt=""
  ui_success "$device is ready."
done

printf "\n"
ui_success "All selected drives have been processed."