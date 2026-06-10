#!/bin/bash

# lib/disk.sh
# Block device helpers: validation, mounting, copying, cleanup.
# Sourced by ventoy-creator.sh: do not run directly.

# Checks whether a given name exists as a block device
disk_exists() {
  local device="$1"
  [ -b "$device" ]
}

# Checks whether a device is the disk hosting the root filesystem.
# Returns 0 (true) if it is the system disk
disk_is_system_disk() {
  local device="$1"
  local root_disk
  root_disk=$(lsblk -no PKNAME "$(findmnt -n -o SOURCE /)" 2>/dev/null)
  [ "$root_disk" = "$(basename "$device")" ]
}

# Resolves the Ventoy data partition path on a given device.
# Prints the partition path e.g. /dev/sdd1
disk_get_ventoy_part() {
  local device="$1"
  lsblk -o NAME,LABEL -nr "$device" | awk '$2=="Ventoy"{print "/dev/" $1}'
}

# Checks free space on a mount point against a required byte count
disk_has_space() {
  local mount="$1"
  local required="$2"
  local available
  available=$(df -B1 --output=avail "$mount" | tail -1)
  [ "$available" -ge "$required" ]
}

# Mounts a partition to a path, creating the mount point if needed
disk_mount() {
  local part="$1" mnt="$2"
  mkdir -p "$mnt"
  mount "$part" "$mnt"
}

# Unmounts and removes a temporary mount point
disk_unmount() {
  local mnt="$1"
  umount "$mnt"
  rmdir "$mnt"
}

# Copies all ISOs from source dir to destination with progress and checksum verification.
# Optional third argument: path to a status file; receives "copying:NN" lines as rsync progresses.
disk_copy_isos() {
  local src="$1" dst="$2" status_file="${3:-}"
  if [ -n "$status_file" ]; then
    rsync "$src/"*.iso "$dst"/ -h --info=progress2 2>&1 | \
      tr '\r' '\n' | \
      while IFS= read -r line; do
        if [[ "$line" =~ [[:space:]]([0-9]+)% ]]; then
          printf "copying:%s" "${BASH_REMATCH[1]}" > "$status_file"
          # Log file-completion summaries (contain "(xfr#") but not mid-file updates
          [[ "$line" == *"(xfr#"* ]] && printf "%s\n" "$line"
        else
          printf "%s\n" "$line"
        fi
      done
    return "${PIPESTATUS[0]}"
  else
    rsync "$src/"*.iso "$dst"/ -h --info=progress2
  fi
}

# Returns the total size in bytes of all ISOs in a directory
disk_iso_total_size() {
  local src="$1"
  du -sb "$src/"*.iso 2>/dev/null | awk '{sum += $1} END {print sum+0}'
}